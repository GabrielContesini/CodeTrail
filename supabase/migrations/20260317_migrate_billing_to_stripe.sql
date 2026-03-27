alter table public.billing_config
  alter column billing_provider set default 'stripe';

alter table public.customers
  alter column gateway_provider set default 'stripe';

alter table public.subscriptions
  alter column gateway_provider set default 'stripe';

alter table public.payments
  alter column gateway_provider set default 'stripe';

alter table public.billing_events
  alter column gateway_provider set default 'stripe';

insert into public.billing_config (
  id,
  billing_provider,
  trial_enabled,
  trial_days_default,
  founding_plan_enabled,
  founding_requires_allowlist
)
values (
  'default',
  'stripe',
  true,
  7,
  true,
  false
)
on conflict (id) do update
  set billing_provider = 'stripe';

update public.customers
set gateway_provider = 'stripe',
    gateway_customer_id = null,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'provider_migrated_to', 'stripe',
      'provider_migration_requires_new_checkout', true
    ),
    updated_at = timezone('utc', now())
where gateway_provider = 'mercadopago';

update public.subscriptions s
set gateway_provider = 'stripe',
    gateway_subscription_id = null,
    status = case
      when p.code = 'free' then s.status
      when s.status in ('active', 'trialing', 'past_due', 'unpaid', 'incomplete') then 'expired'
      else s.status
    end,
    status_detail = case
      when p.code = 'free' then s.status_detail
      else 'migrated_to_stripe'
    end,
    metadata = coalesce(s.metadata, '{}'::jsonb) || jsonb_build_object(
      'provider_migrated_to', 'stripe',
      'provider_migration_requires_new_checkout', p.code <> 'free'
    ),
    updated_at = timezone('utc', now())
from public.plans p
where p.id = s.plan_id
  and s.gateway_provider = 'mercadopago';

create or replace function public.ensure_default_billing_for_user(
  target_user_id uuid,
  target_email text,
  target_full_name text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  free_plan_id uuid;
  customer_row public.customers;
  config_row public.billing_config;
  provider_name text := 'stripe';
  now_utc timestamptz := timezone('utc', now());
  trial_end timestamptz;
begin
  select id
  into free_plan_id
  from public.plans
  where code = 'free'
  limit 1;

  if free_plan_id is null then
    return;
  end if;

  config_row := public.current_billing_config();
  provider_name := coalesce(config_row.billing_provider, 'stripe');

  if config_row.id is not null
     and config_row.trial_enabled
     and config_row.trial_days_default > 0 then
    trial_end := now_utc + make_interval(days => config_row.trial_days_default);
  else
    trial_end := null;
  end if;

  insert into public.customers (
    user_id,
    gateway_provider,
    billing_email,
    full_name
  )
  values (
    target_user_id,
    provider_name,
    coalesce(target_email, ''),
    coalesce(target_full_name, '')
  )
  on conflict (user_id, gateway_provider) do update
    set billing_email = excluded.billing_email,
        full_name = case
          when coalesce(public.customers.full_name, '') = '' then excluded.full_name
          else public.customers.full_name
        end;

  select *
  into customer_row
  from public.customers
  where user_id = target_user_id
    and gateway_provider = provider_name
  limit 1;

  if not exists (
    select 1
    from public.subscriptions s
    join public.plans p on p.id = s.plan_id
    where s.user_id = target_user_id
      and p.code = 'free'
  ) then
    insert into public.subscriptions (
      user_id,
      plan_id,
      customer_id,
      gateway_provider,
      status,
      billing_cycle,
      started_at,
      current_period_start,
      trial_ends_at,
      metadata
    )
    values (
      target_user_id,
      free_plan_id,
      customer_row.id,
      provider_name,
      'active',
      'month',
      now_utc,
      now_utc,
      trial_end,
      jsonb_build_object(
        'origin', 'default_free',
        'trial_enabled_at_signup', trial_end is not null
      )
    );
  end if;
end;
$$;
