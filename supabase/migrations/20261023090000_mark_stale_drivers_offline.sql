alter table public.driver_profile
  add column if not exists location_updated_at timestamptz;

-- Stamped server-side so every client version (foreground loop, background task, navigation) acts as a heartbeat.
create or replace function public.stamp_driver_location_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Only online drivers heartbeat; this also keeps the offline sweep from refreshing the stamp.
  if coalesce(new.is_online, false)
    and new.location_lat is not null
    and new.location_lng is not null then
    new.location_updated_at := timezone('utc', now());
  end if;

  return new;
end;
$$;

drop trigger if exists driver_profile_stamp_location_updated_at on public.driver_profile;

create trigger driver_profile_stamp_location_updated_at
before update of location_lat, location_lng, is_online on public.driver_profile
for each row
execute function public.stamp_driver_location_updated_at();

-- Grace period for drivers already online when this ships.
update public.driver_profile
set location_updated_at = timezone('utc', now())
where is_online = true
  and location_updated_at is null;

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
        dp.location_updated_at is null
        or dp.location_updated_at <= timezone('utc', now()) - p_timeout
      )
    returning dp.uuid
  )
  select stale_drivers.uuid
  from stale_drivers;
end;
$$;

revoke execute on function public.mark_stale_drivers_offline(interval) from public, anon, authenticated;

create extension if not exists pg_cron;

select cron.unschedule('mark-stale-drivers-offline')
where exists (select 1 from cron.job where jobname = 'mark-stale-drivers-offline');

select cron.schedule(
  'mark-stale-drivers-offline',
  '* * * * *',
  $$ select public.mark_stale_drivers_offline(interval '10 minutes'); $$
);
