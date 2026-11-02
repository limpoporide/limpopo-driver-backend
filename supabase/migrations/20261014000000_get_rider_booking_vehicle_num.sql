create or replace function public.get_rider_booking_vehicle_num(p_booking_id uuid)
returns table (vehicle_num text)
language sql
stable
security definer
set search_path = ''
as $$
  select vm.vehicle_num::text
  from public.rider_booking rb
  join public.vehicle_management vm
    on vm.assigned = rb.assigned_driver
  where rb.id = p_booking_id
    and rb.rider_id = (select auth.uid())
    and rb.ride_status in ('accepted', 'arrived', 'in_progress', 'completed');
$$;

revoke all on function public.get_rider_booking_vehicle_num(uuid) from public;
grant execute on function public.get_rider_booking_vehicle_num(uuid) to authenticated;