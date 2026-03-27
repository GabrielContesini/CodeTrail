create or replace function public.recalculate_project_progress(
  target_project_id text
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  total_steps integer := 0;
  completed_steps integer := 0;
  next_progress numeric(5,2) := 0;
begin
  if auth.uid() is null or target_project_id is null or target_project_id = '' then
    return;
  end if;

  if not exists (
    select 1
    from public.projects p
    where p.id = target_project_id
      and p.user_id = auth.uid()
  ) then
    raise exception using
      message = 'Project not found for current user.',
      errcode = 'P0001';
  end if;

  select
    count(*),
    count(*) filter (where is_done)
  into total_steps, completed_steps
  from public.project_steps
  where project_id = target_project_id;

  if total_steps > 0 then
    next_progress := round((completed_steps::numeric / total_steps::numeric) * 100, 2);
  end if;

  update public.projects
  set progress_percent = next_progress,
      updated_at = timezone('utc', now())
  where id = target_project_id
    and user_id = auth.uid();
end;
$$;

create or replace function public.upsert_project_step_with_progress(
  target_step jsonb
)
returns public.project_steps
language plpgsql
security invoker
set search_path = public
as $$
declare
  resolved_project_id text := nullif(target_step ->> 'project_id', '');
  resolved_step_id text := coalesce(nullif(target_step ->> 'id', ''), gen_random_uuid()::text);
  resolved_is_done boolean := coalesce((target_step ->> 'is_done')::boolean, false);
  step_row public.project_steps;
begin
  if auth.uid() is null then
    raise exception using
      message = 'Unauthorized request.',
      errcode = 'P0001';
  end if;

  if resolved_project_id is null then
    raise exception using
      message = 'Project step requires a project_id.',
      errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.projects p
    where p.id = resolved_project_id
      and p.user_id = auth.uid()
  ) then
    raise exception using
      message = 'Project not found for current user.',
      errcode = 'P0001';
  end if;

  insert into public.project_steps (
    id,
    project_id,
    title,
    description,
    is_done,
    sort_order,
    completed_at,
    created_at,
    updated_at
  )
  values (
    resolved_step_id,
    resolved_project_id,
    coalesce(nullif(target_step ->> 'title', ''), 'Nova etapa'),
    coalesce(target_step ->> 'description', ''),
    resolved_is_done,
    coalesce((target_step ->> 'sort_order')::integer, 1),
    case
      when resolved_is_done then coalesce((target_step ->> 'completed_at')::timestamptz, timezone('utc', now()))
      else null
    end,
    coalesce((target_step ->> 'created_at')::timestamptz, timezone('utc', now())),
    coalesce((target_step ->> 'updated_at')::timestamptz, timezone('utc', now()))
  )
  on conflict (id) do update
    set project_id = excluded.project_id,
        title = excluded.title,
        description = excluded.description,
        is_done = excluded.is_done,
        sort_order = excluded.sort_order,
        completed_at = excluded.completed_at,
        updated_at = excluded.updated_at
  returning *
  into step_row;

  perform public.recalculate_project_progress(resolved_project_id);
  return step_row;
end;
$$;

create or replace function public.delete_project_step_with_progress(
  target_step_id text
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  resolved_project_id text;
begin
  if auth.uid() is null then
    raise exception using
      message = 'Unauthorized request.',
      errcode = 'P0001';
  end if;

  select ps.project_id
  into resolved_project_id
  from public.project_steps ps
  join public.projects p on p.id = ps.project_id
  where ps.id = target_step_id
    and p.user_id = auth.uid()
  limit 1;

  if resolved_project_id is null then
    return;
  end if;

  delete from public.project_steps
  where id = target_step_id
    and project_id = resolved_project_id;

  perform public.recalculate_project_progress(resolved_project_id);
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.ensure_default_billing_for_user(uuid, text, text) from public, anon, authenticated;
revoke all on function public.get_my_billing_snapshot() from public, anon;
revoke all on function public.recalculate_project_progress(text) from public, anon;
revoke all on function public.upsert_project_step_with_progress(jsonb) from public, anon;
revoke all on function public.delete_project_step_with_progress(text) from public, anon;

grant execute on function public.get_my_billing_snapshot() to authenticated, service_role;
grant execute on function public.recalculate_project_progress(text) to authenticated, service_role;
grant execute on function public.upsert_project_step_with_progress(jsonb) to authenticated, service_role;
grant execute on function public.delete_project_step_with_progress(text) to authenticated, service_role;
grant execute on function public.ensure_default_billing_for_user(uuid, text, text) to service_role;
