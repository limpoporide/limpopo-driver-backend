-- Returns the driver's current is_online so the client can detect a server-side offline flip.
drop function if exists public.driver_heartbeat();

create or replace function public.driver_heartbeat()
returns boolean
language sql
set search_path = public
as $$
  with touched as (
    update public.driver_profile
    set last_seen_at = now()
    where uuid = auth.uid()
      and is_online = true
    returning 1
  )
  select exists (select 1 from touched);
$$;

revoke execute on function public.driver_heartbeat() from public, anon;
grant execute on function public.driver_heartbeat() to authenticated;

-- 15 minutes tolerates OS throttling of background work on iOS and battery-saver Android.
create or replace function public.mark_stale_drivers_offline(
  p_timeout interval default interval '15 minutes'
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
        coalesce(dp.last_seen_at, dp.location_updated_at) is null
        or coalesce(dp.last_seen_at, dp.location_updated_at) <= now() - p_timeout
      )
    returning dp.uuid
  )
  select stale_drivers.uuid
  from stale_drivers;
end;
$$;

revoke execute on function public.mark_stale_drivers_offline(interval) from public, anon, authenticated;

select cron.unschedule('mark-stale-drivers-offline')
where exists (select 1 from cron.job where jobname = 'mark-stale-drivers-offline');

select cron.schedule(
  'mark-stale-drivers-offline',
  '* * * * *',
  $$ select public.mark_stale_drivers_offline(interval '15 minutes'); $$
);
