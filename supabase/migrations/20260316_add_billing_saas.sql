create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code in ('free', 'pro', 'founding')),
  name text not null,
  description text not null default '',
  price_cents integer not null default 0 check (price_cents >= 0),
  currency text not null default 'BRL',
  interval text not null default 'month' check (interval in ('month', 'year')),
  is_active boolean not null default true,
  is_public boolean not null default true,
  trial_days integer not null default 0 check (trial_days >= 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.plan_features (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default false,
  limit_value integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (plan_id, feature_key)
);

create table if not exists public.billing_config (
  id text primary key default 'default',
  billing_provider text not null default 'mercadopago',
  trial_enabled boolean not null default true,
  trial_days_default integer not null default 7 check (trial_days_default >= 0),
  founding_plan_enabled boolean not null default true,
  founding_requires_allowlist boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.founder_eligibility (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  email text,
  is_eligible boolean not null default true,
  notes text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (user_id is not null or email is not null)
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  gateway_provider text not null default 'mercadopago',
  gateway_customer_id text,
  billing_email text not null,
  full_name text not null,
  tax_document text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (user_id, gateway_provider)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null references public.plans(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete set null,
  gateway_provider text not null default 'mercadopago',
  gateway_subscription_id text,
  external_reference text,
  status text not null default 'active' check (
    status in ('trialing', 'active', 'past_due', 'unpaid', 'canceled', 'expired', 'incomplete')
  ),
  status_detail text,
  billing_cycle text not null default 'month' check (billing_cycle in ('month', 'year')),
  started_at timestamptz not null default timezone('utc', now()),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  canceled_at timestamptz,
  trial_ends_at timestamptz,
  grace_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  gateway_provider text not null default 'mercadopago',
  gateway_payment_id text,
  external_reference text,
  amount_cents integer not null default 0 check (amount_cents >= 0),
  currency text not null default 'BRL',
  status text not null default 'pending',
  status_detail text,
  paid_at timestamptz,
  invoice_url text,
  receipt_url text,
  raw_payload jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.billing_events (
  id uuid primary key default gen_random_uuid(),
  gateway_provider text not null default 'mercadopago',
  event_type text not null,
  event_id text not null unique,
  processed boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_plan_features_plan_id on public.plan_features(plan_id);
create index if not exists idx_founder_eligibility_user_id on public.founder_eligibility(user_id);
create index if not exists idx_founder_eligibility_email on public.founder_eligibility(lower(email));
create index if not exists idx_customers_user_id_provider on public.customers(user_id, gateway_provider);
create index if not exists idx_subscriptions_user_id_created_at on public.subscriptions(user_id, created_at desc);
create index if not exists idx_subscriptions_gateway_subscription_id on public.subscriptions(gateway_subscription_id);
create index if not exists idx_subscriptions_external_reference on public.subscriptions(external_reference);
create index if not exists idx_payments_user_id_created_at on public.payments(user_id, created_at desc);
create index if not exists idx_payments_subscription_id on public.payments(subscription_id);
create index if not exists idx_payments_gateway_payment_id on public.payments(gateway_payment_id);
create unique index if not exists idx_payments_gateway_payment_id_unique
on public.payments(gateway_payment_id)
where gateway_payment_id is not null;

drop trigger if exists set_plans_updated_at on public.plans;
create trigger set_plans_updated_at
before update on public.plans
for each row execute function public.set_updated_at();

drop trigger if exists set_plan_features_updated_at on public.plan_features;
create trigger set_plan_features_updated_at
before update on public.plan_features
for each row execute function public.set_updated_at();

drop trigger if exists set_billing_config_updated_at on public.billing_config;
create trigger set_billing_config_updated_at
before update on public.billing_config
for each row execute function public.set_updated_at();

drop trigger if exists set_founder_eligibility_updated_at on public.founder_eligibility;
create trigger set_founder_eligibility_updated_at
before update on public.founder_eligibility
for each row execute function public.set_updated_at();

drop trigger if exists set_customers_updated_at on public.customers;
create trigger set_customers_updated_at
before update on public.customers
for each row execute function public.set_updated_at();

drop trigger if exists set_subscriptions_updated_at on public.subscriptions;
create trigger set_subscriptions_updated_at
before update on public.subscriptions
for each row execute function public.set_updated_at();

drop trigger if exists set_payments_updated_at on public.payments;
create trigger set_payments_updated_at
before update on public.payments
for each row execute function public.set_updated_at();

create or replace function public.current_billing_config()
returns public.billing_config
language sql
stable
as $$
  select *
  from public.billing_config
  where id = 'default'
  limit 1;
$$;

create or replace function public.is_founding_eligible(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
as $$
declare
  config_row public.billing_config;
  current_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  config_row := public.current_billing_config();

  if config_row.id is null or not config_row.founding_plan_enabled then
    return false;
  end if;

  if not config_row.founding_requires_allowlist then
    return true;
  end if;

  return exists (
    select 1
    from public.founder_eligibility fe
    where fe.is_eligible
      and (
        fe.user_id = target_user_id
        or (
          fe.email is not null
          and current_email <> ''
          and lower(fe.email) = current_email
        )
      )
  );
end;
$$;

create or replace function public.billing_subscription_has_access(target_subscription public.subscriptions)
returns boolean
language plpgsql
stable
as $$
begin
  if target_subscription.id is null then
    return false;
  end if;

  if target_subscription.status in ('active', 'trialing') then
    return true;
  end if;

  if target_subscription.status in ('past_due', 'unpaid')
     and target_subscription.grace_until is not null
     and target_subscription.grace_until > timezone('utc', now()) then
    return true;
  end if;

  if target_subscription.status = 'canceled'
     and target_subscription.current_period_end is not null
     and target_subscription.current_period_end > timezone('utc', now()) then
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.billing_subscription_is_trialing(target_subscription public.subscriptions)
returns boolean
language plpgsql
stable
as $$
begin
  return target_subscription.id is not null
    and target_subscription.trial_ends_at is not null
    and target_subscription.trial_ends_at > timezone('utc', now())
    and target_subscription.status in ('active', 'trialing');
end;
$$;

create or replace function public.current_paid_subscription(target_user_id uuid default auth.uid())
returns public.subscriptions
language sql
stable
as $$
  select s.*
  from public.subscriptions s
  join public.plans p on p.id = s.plan_id
  where s.user_id = target_user_id
    and p.code in ('pro', 'founding')
    and public.billing_subscription_has_access(s)
  order by
    case p.code when 'founding' then 0 else 1 end,
    coalesce(s.current_period_end, s.updated_at) desc,
    s.created_at desc
  limit 1;
$$;

create or replace function public.current_free_subscription(target_user_id uuid default auth.uid())
returns public.subscriptions
language sql
stable
as $$
  select s.*
  from public.subscriptions s
  join public.plans p on p.id = s.plan_id
  where s.user_id = target_user_id
    and p.code = 'free'
  order by s.created_at desc
  limit 1;
$$;

create or replace function public.current_effective_subscription(target_user_id uuid default auth.uid())
returns public.subscriptions
language plpgsql
stable
as $$
declare
  paid_subscription public.subscriptions;
  free_subscription public.subscriptions;
begin
  paid_subscription := public.current_paid_subscription(target_user_id);
  if paid_subscription.id is not null then
    return paid_subscription;
  end if;

  free_subscription := public.current_free_subscription(target_user_id);
  return free_subscription;
end;
$$;

create or replace function public.current_effective_plan_id(target_user_id uuid default auth.uid())
returns uuid
language plpgsql
stable
as $$
declare
  effective_subscription public.subscriptions;
begin
  effective_subscription := public.current_effective_subscription(target_user_id);
  return effective_subscription.plan_id;
end;
$$;

create or replace function public.current_effective_plan_code(target_user_id uuid default auth.uid())
returns text
language sql
stable
as $$
  select p.code
  from public.plans p
  where p.id = public.current_effective_plan_id(target_user_id);
$$;

create or replace function public.current_feature_plan_id(target_user_id uuid default auth.uid())
returns uuid
language plpgsql
stable
as $$
declare
  effective_subscription public.subscriptions;
  pro_plan_id uuid;
begin
  effective_subscription := public.current_effective_subscription(target_user_id);

  if effective_subscription.id is not null
     and public.billing_subscription_is_trialing(effective_subscription) then
    select id
    into pro_plan_id
    from public.plans
    where code = 'pro'
    limit 1;

    if pro_plan_id is not null then
      return pro_plan_id;
    end if;
  end if;

  return effective_subscription.plan_id;
end;
$$;

create or replace function public.is_user_premium(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
as $$
declare
  effective_subscription public.subscriptions;
  plan_code text;
begin
  effective_subscription := public.current_effective_subscription(target_user_id);
  if effective_subscription.id is null then
    return false;
  end if;

  if public.billing_subscription_is_trialing(effective_subscription) then
    return true;
  end if;

  select code
  into plan_code
  from public.plans
  where id = effective_subscription.plan_id;

  return plan_code in ('pro', 'founding')
    and public.billing_subscription_has_access(effective_subscription);
end;
$$;

create or replace function public.is_user_trialing(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
as $$
declare
  effective_subscription public.subscriptions;
begin
  effective_subscription := public.current_effective_subscription(target_user_id);
  return public.billing_subscription_is_trialing(effective_subscription);
end;
$$;

create or replace function public.is_user_in_grace_period(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
as $$
declare
  paid_subscription public.subscriptions;
begin
  paid_subscription := public.current_paid_subscription(target_user_id);
  return paid_subscription.id is not null
    and paid_subscription.status in ('past_due', 'unpaid')
    and paid_subscription.grace_until is not null
    and paid_subscription.grace_until > timezone('utc', now());
end;
$$;

create or replace function public.user_has_lost_premium_access(target_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
as $$
begin
  return not public.is_user_premium(target_user_id)
    and exists (
      select 1
      from public.subscriptions s
      join public.plans p on p.id = s.plan_id
      where s.user_id = target_user_id
        and p.code in ('pro', 'founding')
    );
end;
$$;

create or replace function public.has_feature_access(
  target_feature_key text,
  target_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
as $$
declare
  feature_plan_id uuid;
  feature_enabled boolean;
begin
  feature_plan_id := public.current_feature_plan_id(target_user_id);
  if feature_plan_id is null then
    return false;
  end if;

  select pf.enabled
  into feature_enabled
  from public.plan_features pf
  where pf.plan_id = feature_plan_id
    and pf.feature_key = target_feature_key
  limit 1;

  return coalesce(feature_enabled, false);
end;
$$;

create or replace function public.get_feature_limit(
  target_feature_key text,
  target_user_id uuid default auth.uid()
)
returns integer
language plpgsql
stable
as $$
declare
  feature_plan_id uuid;
  feature_limit integer;
begin
  feature_plan_id := public.current_feature_plan_id(target_user_id);
  if feature_plan_id is null then
    return null;
  end if;

  select pf.limit_value
  into feature_limit
  from public.plan_features pf
  where pf.plan_id = feature_plan_id
    and pf.feature_key = target_feature_key
  limit 1;

  return feature_limit;
end;
$$;

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
    'mercadopago',
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
    and gateway_provider = 'mercadopago'
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
      'mercadopago',
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

create or replace function public.get_my_billing_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  target_user_id uuid := auth.uid();
  effective_subscription public.subscriptions;
  effective_plan_id uuid;
  feature_plan_id uuid;
  current_customer public.customers;
  config_row public.billing_config;
begin
  if target_user_id is null then
    return '{}'::jsonb;
  end if;

  effective_subscription := public.current_effective_subscription(target_user_id);
  effective_plan_id := effective_subscription.plan_id;
  feature_plan_id := public.current_feature_plan_id(target_user_id);
  config_row := public.current_billing_config();

  select *
  into current_customer
  from public.customers
  where user_id = target_user_id
  order by updated_at desc
  limit 1;

  return jsonb_build_object(
    'customer',
    case
      when current_customer.id is null then null
      else jsonb_build_object(
        'id', current_customer.id,
        'gateway_provider', current_customer.gateway_provider,
        'gateway_customer_id', current_customer.gateway_customer_id,
        'billing_email', current_customer.billing_email,
        'full_name', current_customer.full_name,
        'tax_document', current_customer.tax_document,
        'metadata', current_customer.metadata,
        'created_at', current_customer.created_at,
        'updated_at', current_customer.updated_at
      )
    end,
    'subscription',
    case
      when effective_subscription.id is null then null
      else jsonb_build_object(
        'id', effective_subscription.id,
        'plan_id', effective_subscription.plan_id,
        'customer_id', effective_subscription.customer_id,
        'gateway_provider', effective_subscription.gateway_provider,
        'gateway_subscription_id', effective_subscription.gateway_subscription_id,
        'external_reference', effective_subscription.external_reference,
        'status', effective_subscription.status,
        'status_detail', effective_subscription.status_detail,
        'billing_cycle', effective_subscription.billing_cycle,
        'started_at', effective_subscription.started_at,
        'current_period_start', effective_subscription.current_period_start,
        'current_period_end', effective_subscription.current_period_end,
        'cancel_at_period_end', effective_subscription.cancel_at_period_end,
        'canceled_at', effective_subscription.canceled_at,
        'trial_ends_at', effective_subscription.trial_ends_at,
        'grace_until', effective_subscription.grace_until,
        'metadata', effective_subscription.metadata,
        'created_at', effective_subscription.created_at,
        'updated_at', effective_subscription.updated_at,
        'is_premium', public.is_user_premium(target_user_id),
        'is_trialing', public.is_user_trialing(target_user_id),
        'is_in_grace_period', public.is_user_in_grace_period(target_user_id),
        'has_lost_access', public.user_has_lost_premium_access(target_user_id)
      )
    end,
    'current_plan',
    (
      select jsonb_build_object(
        'id', p.id,
        'code', p.code,
        'name', p.name,
        'description', p.description,
        'price_cents', p.price_cents,
        'currency', p.currency,
        'interval', p.interval,
        'is_active', p.is_active,
        'is_public', p.is_public,
        'trial_days', p.trial_days,
        'metadata', p.metadata,
        'created_at', p.created_at,
        'updated_at', p.updated_at
      )
      from public.plans p
      where p.id = effective_plan_id
    ),
    'features',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'feature_key', pf.feature_key,
            'enabled', pf.enabled,
            'limit_value', pf.limit_value
          )
          order by pf.feature_key
        )
        from public.plan_features pf
        where pf.plan_id = feature_plan_id
      ),
      '[]'::jsonb
    ),
    'available_plans',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', p.id,
            'code', p.code,
            'name', p.name,
            'description', p.description,
            'price_cents', p.price_cents,
            'currency', p.currency,
            'interval', p.interval,
            'is_active', p.is_active,
            'is_public', p.is_public,
            'trial_days', p.trial_days,
            'metadata', p.metadata,
            'features',
            coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'feature_key', pf.feature_key,
                    'enabled', pf.enabled,
                    'limit_value', pf.limit_value
                  )
                  order by pf.feature_key
                )
                from public.plan_features pf
                where pf.plan_id = p.id
              ),
              '[]'::jsonb
            )
          )
          order by case p.code
            when 'free' then 0
            when 'pro' then 1
            when 'founding' then 2
            else 99
          end
        )
        from public.plans p
        where p.is_active
          and (
            p.is_public
            or (p.code = 'founding' and public.is_founding_eligible(target_user_id))
          )
      ),
      '[]'::jsonb
    ),
    'payments',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', payment_rows.id,
            'subscription_id', payment_rows.subscription_id,
            'gateway_provider', payment_rows.gateway_provider,
            'gateway_payment_id', payment_rows.gateway_payment_id,
            'external_reference', payment_rows.external_reference,
            'amount_cents', payment_rows.amount_cents,
            'currency', payment_rows.currency,
            'status', payment_rows.status,
            'status_detail', payment_rows.status_detail,
            'paid_at', payment_rows.paid_at,
            'invoice_url', payment_rows.invoice_url,
            'receipt_url', payment_rows.receipt_url,
            'metadata', payment_rows.metadata,
            'raw_payload', payment_rows.raw_payload,
            'created_at', payment_rows.created_at,
            'updated_at', payment_rows.updated_at
          )
          order by payment_rows.created_at desc
        )
        from (
          select *
          from public.payments
          where user_id = target_user_id
          order by created_at desc
          limit 20
        ) as payment_rows
      ),
      '[]'::jsonb
    ),
    'founding_eligible', public.is_founding_eligible(target_user_id),
    'config', jsonb_build_object(
      'billing_provider', coalesce(config_row.billing_provider, 'mercadopago'),
      'trial_enabled', coalesce(config_row.trial_enabled, false),
      'trial_days_default', coalesce(config_row.trial_days_default, 0),
      'founding_plan_enabled', coalesce(config_row.founding_plan_enabled, false)
    )
  );
end;
$$;

create or replace function public.enforce_billing_entitlement()
returns trigger
language plpgsql
as $$
declare
  target_user_id uuid;
  required_feature text := nullif(TG_ARGV[0], '');
  limit_feature text := nullif(TG_ARGV[1], '');
  feature_limit integer;
  current_total integer;
begin
  target_user_id := (to_jsonb(new) ->> 'user_id')::uuid;
  if target_user_id is null then
    return new;
  end if;

  if required_feature is not null
     and not public.has_feature_access(required_feature, target_user_id) then
    raise exception using
      message = format('Seu plano atual não libera o recurso %s.', required_feature),
      errcode = 'P0001';
  end if;

  if limit_feature is not null and TG_OP = 'INSERT' then
    feature_limit := public.get_feature_limit(limit_feature, target_user_id);
    if feature_limit is not null then
      execute format(
        'select count(*) from public.%I where user_id = $1',
        TG_TABLE_NAME
      )
      into current_total
      using target_user_id;

      if current_total >= feature_limit then
        raise exception using
          message = format('Seu plano atual atingiu o limite de %s.', limit_feature),
          errcode = 'P0001';
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_notes_billing on public.study_notes;
create trigger enforce_notes_billing
before insert or update on public.study_notes
for each row execute function public.enforce_billing_entitlement('', 'notes_limit');

drop trigger if exists enforce_projects_billing on public.projects;
create trigger enforce_projects_billing
before insert or update on public.projects
for each row execute function public.enforce_billing_entitlement('', 'projects_limit');

drop trigger if exists enforce_flashcards_billing on public.flashcards;
create trigger enforce_flashcards_billing
before insert or update on public.flashcards
for each row execute function public.enforce_billing_entitlement('flashcards_access', 'flashcards_limit');

drop trigger if exists enforce_mind_maps_billing on public.mind_maps;
create trigger enforce_mind_maps_billing
before insert or update on public.mind_maps
for each row execute function public.enforce_billing_entitlement('mind_maps_access', 'mind_maps_limit');

alter table public.plans enable row level security;
alter table public.plan_features enable row level security;
alter table public.billing_config enable row level security;
alter table public.founder_eligibility enable row level security;
alter table public.customers enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.billing_events enable row level security;

drop policy if exists "plans_select_available" on public.plans;
create policy "plans_select_available"
on public.plans
for select
to authenticated
using (
  is_active
  and (
    is_public
    or (code = 'founding' and public.is_founding_eligible(auth.uid()))
  )
);

drop policy if exists "plan_features_select_available" on public.plan_features;
create policy "plan_features_select_available"
on public.plan_features
for select
to authenticated
using (
  exists (
    select 1
    from public.plans p
    where p.id = plan_id
      and p.is_active
      and (
        p.is_public
        or (p.code = 'founding' and public.is_founding_eligible(auth.uid()))
      )
  )
);

drop policy if exists "customers_select_own" on public.customers;
create policy "customers_select_own"
on public.customers
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own"
on public.subscriptions
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "payments_select_own" on public.payments;
create policy "payments_select_own"
on public.payments
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "flashcards_all_own" on public.flashcards;
create policy "flashcards_all_own"
on public.flashcards
for all
to authenticated
using (
  auth.uid() = user_id
  and public.has_feature_access('flashcards_access', auth.uid())
)
with check (
  auth.uid() = user_id
  and public.has_feature_access('flashcards_access', auth.uid())
);

drop policy if exists "mind_maps_all_own" on public.mind_maps;
create policy "mind_maps_all_own"
on public.mind_maps
for all
to authenticated
using (
  auth.uid() = user_id
  and public.has_feature_access('mind_maps_access', auth.uid())
)
with check (
  auth.uid() = user_id
  and public.has_feature_access('mind_maps_access', auth.uid())
);

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
  'mercadopago',
  true,
  7,
  true,
  false
)
on conflict (id) do update
  set billing_provider = excluded.billing_provider,
      trial_enabled = excluded.trial_enabled,
      trial_days_default = excluded.trial_days_default,
      founding_plan_enabled = excluded.founding_plan_enabled,
      founding_requires_allowlist = excluded.founding_requires_allowlist;

insert into public.plans (
  code,
  name,
  description,
  price_cents,
  currency,
  interval,
  is_active,
  is_public,
  trial_days,
  metadata
)
values
  (
    'free',
    'Free',
    'Acesso básico ao app com limites menores e sem recursos premium.',
    0,
    'BRL',
    'month',
    true,
    true,
    0,
    jsonb_build_object('badge', 'Free')
  ),
  (
    'pro',
    'Pro',
    'Acesso completo aos recursos premium do produto.',
    2500,
    'BRL',
    'month',
    true,
    true,
    7,
    jsonb_build_object('badge', 'Pro', 'highlight', true)
  ),
  (
    'founding',
    'Founding',
    'Plano anual com todos os recursos do Pro e condição especial para membros fundadores.',
    27000,
    'BRL',
    'year',
    true,
    true,
    7,
    jsonb_build_object('badge', 'Founding', 'founding', true)
  )
on conflict (code) do update
  set name = excluded.name,
      description = excluded.description,
      price_cents = excluded.price_cents,
      currency = excluded.currency,
      interval = excluded.interval,
      is_active = excluded.is_active,
      is_public = excluded.is_public,
      trial_days = excluded.trial_days,
      metadata = excluded.metadata;

delete from public.plan_features
where plan_id in (
  select id
  from public.plans
  where code in ('free', 'pro', 'founding')
);

insert into public.plan_features (plan_id, feature_key, enabled, limit_value)
select p.id, feature_key, enabled, limit_value
from public.plans p
cross join (
  values
    ('free', 'notes_access', true, null),
    ('free', 'flashcards_access', false, 0),
    ('free', 'mind_maps_access', false, 0),
    ('free', 'analytics_access', false, null),
    ('free', 'ai_generation', false, null),
    ('free', 'notes_limit', true, 40),
    ('free', 'projects_limit', true, 3),
    ('free', 'flashcards_limit', false, 0),
    ('free', 'mind_maps_limit', false, 0),
    ('free', 'founding_badge', false, null),
    ('pro', 'notes_access', true, null),
    ('pro', 'flashcards_access', true, null),
    ('pro', 'mind_maps_access', true, null),
    ('pro', 'analytics_access', true, null),
    ('pro', 'ai_generation', true, null),
    ('pro', 'notes_limit', true, 500),
    ('pro', 'projects_limit', true, 30),
    ('pro', 'flashcards_limit', true, 2000),
    ('pro', 'mind_maps_limit', true, 300),
    ('pro', 'founding_badge', false, null),
    ('founding', 'notes_access', true, null),
    ('founding', 'flashcards_access', true, null),
    ('founding', 'mind_maps_access', true, null),
    ('founding', 'analytics_access', true, null),
    ('founding', 'ai_generation', true, null),
    ('founding', 'notes_limit', true, 500),
    ('founding', 'projects_limit', true, 30),
    ('founding', 'flashcards_limit', true, 2000),
    ('founding', 'mind_maps_limit', true, 300),
    ('founding', 'founding_badge', true, null)
) as feature_rows(plan_code, feature_key, enabled, limit_value)
where p.code = feature_rows.plan_code;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email
  )
  on conflict (id) do nothing;

  perform public.ensure_default_billing_for_user(
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );

  return new;
end;
$$;

select public.ensure_default_billing_for_user(
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data ->> 'full_name', '')
)
from auth.users u;
