do $$
declare
  v_constraint_name text;
begin
  select con.conname
  into v_constraint_name
  from pg_constraint con
  join pg_class rel
    on rel.oid = con.conrelid
  join pg_namespace nsp
    on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname = 'driver_transaction'
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%type in%wallet_topup%payout%';

  if v_constraint_name is not null then
    execute format('alter table public.driver_transaction drop constraint %I', v_constraint_name);
  end if;

  alter table public.driver_transaction
  add constraint driver_transaction_type_check
  check (type in ('wallet_topup', 'payout', 'ride_payment'));
end
$$;