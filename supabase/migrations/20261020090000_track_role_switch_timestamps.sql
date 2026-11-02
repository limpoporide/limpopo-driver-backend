alter table public.rider_profile
add column if not exists switched_to_driver_at timestamptz;

alter table public.driver_profile
add column if not exists switched_to_rider_at timestamptz;