update public.billing_config
set
  founding_plan_enabled = true,
  founding_requires_allowlist = false
where id = 'default';

update public.plans
set
  is_public = true,
  is_active = true
where code = 'founding';
