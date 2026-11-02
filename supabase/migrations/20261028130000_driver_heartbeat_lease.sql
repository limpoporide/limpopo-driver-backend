 alter table public.driver_profile
  add column if not exists last_seen_at timestamptz;

-- location writes and going online both count as a sign of life.
create or replace function public.stamp_driver_location_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce(new.is_online, false) then
    new.last_seen_at := now();

    if new.location_lat is not null and new.location_lng is not null then
      new.location_updated_at := now();
    end if;
  end if;

  return new;
end;
$$;

-- grace period for drivers already online when this ships.
update public.driver_profile
set last_seen_at = now()
where is_online = true
  and last_seen_at is null;

-- heartbeat that does not depend on the os delivering a gps fix.
create or replace function public.driver_heartbeat()
returns void
language sql
set search_path = public
as $$
  update public.driver_profile
  set last_seen_at = now()
  where uuid = auth.uid()
    and is_online = true;
$$;

revoke execute on function public.driver_heartbeat() from public, anon;
grant execute on function public.driver_heartbeat() to authenticated;

create or replace function public.mark_stale_drivers_offline(
  p_timeout interval default interval '10 minutes'
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

create extension if not exists pg_cron;

select cron.unschedule('mark-stale-drivers-offline')
where exists (select 1 from cron.job where jobname = 'mark-stale-drivers-offline');

select cron.schedule(
  'mark-stale-drivers-offline',
  '* * * * *',
  $$ select public.mark_stale_drivers_offline(interval '10 minutes'); $$
);
