create or replace function public.get_rider_booking_payout_details(p_booking_id uuid)
returns table (
  payout_account_number text,
  payout_bank_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select dp.payout_account_number, dp.payout_bank_name
  from public.rider_booking rb
  join public.driver_profile dp
    on dp.uuid = rb.assigned_driver
  where rb.id = p_booking_id
    and rb.rider_id = (select auth.uid())
    and rb.ride_status = 'completed'
    and rb.payment_status is distinct from 'paid'
    and nullif(btrim(dp.payout_account_number), '') is not null
    and nullif(btrim(dp.payout_bank_name), '') is not null;
$$;

revoke all on function public.get_rider_booking_payout_details(uuid) from public;
grant execute on function public.get_rider_booking_payout_details(uuid) to authenticated;