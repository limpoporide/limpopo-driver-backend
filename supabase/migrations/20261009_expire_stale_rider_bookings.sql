create or replace function public.expire_stale_open_rider_bookings(
  p_expiry interval default interval '2 minutes'
)
returns table (
  booking_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with expired_bookings as (
    update public.rider_booking rb
    set ride_status = 'expired',
        updated_at = timezone('utc', now())
    where rb.ride_status = 'open'
      and rb.assigned_driver is null
      and rb.created_at <= timezone('utc', now()) - p_expiry
      and not exists (
        select 1
        from public.schedule_booking sb
        where sb.converted_rider_booking_id = rb.id
      )
    returning rb.id
  )
  select expired_bookings.id
  from expired_bookings;
end;
$$;

grant execute on function public.expire_stale_open_rider_bookings(interval) to authenticated 