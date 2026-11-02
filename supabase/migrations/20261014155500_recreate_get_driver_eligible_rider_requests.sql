drop function if exists public.get_driver_eligible_rider_requests();

create function public.get_driver_eligible_rider_requests()
returns table (
  id uuid,
  rider_id uuid,
  pick_up text,
  pickup_lat double precision,
  pickup_lng double precision,
  drop_off text,
  drop_lat double precision,
  drop_lng double precision,
  total_fare double precision,
  payment_method text,
  total_km double precision,
  total_time double precision,
  assigned_driver uuid,
  ride_status text,
  created_at timestamptz,
  rider_first_name text,
  rider_last_name text,
  rider_phone_num text,
  rider_profile_img text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid := (select auth.uid());
  v_is_online boolean := false;
  v_driver_lat double precision;
  v_driver_lng double precision;
  v_active_booking public.rider_booking%rowtype;
  v_can_receive_requests boolean := false;
  v_distance_to_dropoff_meters double precision;
  v_dropoff_radius_meters constant double precision := 400;
begin
  if v_driver_id is null then
    raise exception 'Authentication required';
  end if;

  select
    coalesce(dp.is_online, false),
    dp.location_lat,
    dp.location_lng
  into
    v_is_online,
    v_driver_lat,
    v_driver_lng
  from public.driver_profile dp
  where dp.uuid = v_driver_id;

  if not v_is_online then
    return;
  end if;

  select rb.*
  into v_active_booking
  from public.rider_booking rb
  where rb.assigned_driver = v_driver_id
    and rb.ride_status in ('accepted', 'arrived', 'in_progress')
  order by rb.created_at desc
  limit 1;

  if not found then
    v_can_receive_requests := true;
  elsif v_active_booking.ride_status = 'in_progress' then
    if v_driver_lat is not null
      and v_driver_lng is not null
      and v_active_booking.drop_lat is not null
      and v_active_booking.drop_lng is not null then
      v_distance_to_dropoff_meters := 2 * 6371000 * asin(
        sqrt(
          power(sin(radians(v_active_booking.drop_lat - v_driver_lat) / 2), 2)
          + cos(radians(v_driver_lat))
          * cos(radians(v_active_booking.drop_lat))
          * power(sin(radians(v_active_booking.drop_lng - v_driver_lng) / 2), 2)
        )
      );

      v_can_receive_requests := v_distance_to_dropoff_meters <= v_dropoff_radius_meters;
    else
      v_can_receive_requests := false;
    end if;
  else
    v_can_receive_requests := false;
  end if;

  if not v_can_receive_requests then
    return;
  end if;

  return query
  select
    rb.id,
    rb.rider_id,
    rb.pick_up::text,
    rb.pickup_lat::double precision,
    rb.pickup_lng::double precision,
    rb.drop_off::text,
    rb.drop_lat::double precision,
    rb.drop_lng::double precision,
    rb.total_fare::double precision,
    rb.payment_method::text,
    rb.total_km::double precision,
    rb.total_time::double precision,
    rb.assigned_driver,
    rb.ride_status::text,
    rb.created_at,
    rp.first_name::text,
    rp.last_name::text,
    rp.phone_num::text,
    rp.profile_img::text
  from public.rider_booking rb
  left join public.rider_profile rp
    on rp.uuid = rb.rider_id
  where rb.ride_status = 'open'
    and rb.assigned_driver is null
  order by rb.created_at desc;
end;
$$;

revoke all on function public.get_driver_eligible_rider_requests() from public;
grant execute on function public.get_driver_eligible_rider_requests() to authenticated;

