create extension if not exists pg_cron;

-- Keep the interval in sync with LIVE_RIDE_SEARCH_DURATION_SECONDS in the rider app.
select cron.unschedule('expire-stale-open-rider-bookings')
where exists (select 1 from cron.job where jobname = 'expire-stale-open-rider-bookings');

select cron.schedule(
  'expire-stale-open-rider-bookings',
  '* * * * *',
  $$ select public.expire_stale_open_rider_bookings(interval '2 minutes'); $$
);
