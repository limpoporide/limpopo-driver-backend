create or replace function public.mark_stale_drivers_offline(
  p_timeout interval default interval '3 minutes'
)
returns table (
  driver_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with stale_drivers as (
    update public.driver_profile dp
    set is_online = false
    where dp.is_online = true
      and (
        dp.location_updated_at is null
        or dp.location_updated_at <= now() - p_timeout
      )
    returning dp.uuid
  )
  select stale_drivers.uuid
  from stale_drivers;
end;
$$;

create extension if not exists pg_cron;

select cron.unschedule('mark-stale-drivers-offline')
where exists (select 1 from cron.job where jobname = 'mark-stale-drivers-offline');

select cron.schedule(
  'mark-stale-drivers-offline',
  '* * * * *',
  $$ select public.mark_stale_drivers_offline(interval '3 minutes'); $$
);
