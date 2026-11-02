create or replace function public.driver_confirm_external_payment(p_booking_id uuid)
returns public.rider_booking
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid := (select auth.uid());
  v_booking public.rider_booking%rowtype;
  v_driver_reference text;
  v_payment_amount numeric(12, 2);
begin
  if v_driver_id is null then
    raise exception 'Authentication required';
  end if;

  update public.rider_booking rb
  set payment_status = 'paid'
  where rb.id = p_booking_id
    and rb.assigned_driver = v_driver_id
    and rb.ride_status = 'completed'
    and rb.payment_status is distinct from 'paid'
  returning rb.* into v_booking;

  if not found then
    select *
    into v_booking
    from public.rider_booking rb
    where rb.id = p_booking_id
      and rb.assigned_driver = v_driver_id
      and rb.ride_status = 'completed';

    if not found then
      raise exception 'Completed booking not found for this driver';
    end if;
  end if;

  v_payment_amount := round(coalesce(v_booking.total_fare, 0)::numeric, 2);

  if coalesce(v_payment_amount, 0) > 0 then
    v_driver_reference := concat('RIDE_DRIVER_EXT_', p_booking_id::text);

    insert into public.driver_transaction (
      driver_uuid,
      reference,
      type,
      status,
      channel,
      gateway,
      currency,
      amount,
      fee,
      requested_amount,
      sender_name,
      sender_account,
      narration,
      paid_at,
      raw_payload
    )
    values (
      v_driver_id,
      v_driver_reference,
      'ride_payment',
      'success',
      'transfer',
      'driver_confirm_external_payment',
      'NGN',
      v_payment_amount,
      0,
      v_payment_amount,
      'Limpopo Ride',
      p_booking_id::text,
      concat('Direct transfer payment for booking ', p_booking_id::text),
      timezone('utc', now()),
      jsonb_build_object(
        'bookingId', p_booking_id,
        'paymentMethod', v_booking.payment_method,
        'paymentStatus', v_booking.payment_status
      )
    )
    on conflict (reference) do nothing;
  end if;

  return v_booking;
end;
$$;

revoke all on function public.driver_confirm_external_payment(uuid) from public;
grant execute on function public.driver_confirm_external_payment(uuid) to authenticated;