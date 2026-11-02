create or replace function public.driver_release_accepted_rider_booking(p_booking_id uuid)
returns public.rider_booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid := (select auth.uid());
  v_booking public.rider_booking%rowtype;
begin
  if v_driver_id is null then
    raise exception 'Authentication required';
  end if;

  update public.rider_booking rb
  set assigned_driver = null,
      ride_status = 'open'
  where rb.id = p_booking_id
    and rb.assigned_driver = v_driver_id
    and rb.ride_status = 'accepted'
  returning rb.* into v_booking;

  if found then
    return v_booking;
  end if;

  select *
  into v_booking
  from public.rider_booking rb
  where rb.id = p_booking_id
    and rb.assigned_driver = v_driver_id;

  if not found then
    raise exception 'Accepted rider booking not found for this driver';
  end if;

  raise exception 'Only accepted rider bookings can be released';
end;
$$;

revoke all on function public.driver_release_accepted_rider_booking(uuid) from public;
grant execute on function public.driver_release_accepted_rider_booking(uuid) to authenticated;