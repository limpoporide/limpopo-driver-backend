create table if not exists public.ride_call_state (
  booking_id uuid primary key references public.rider_booking(id) on delete cascade,
  call_id uuid not null,
  call_started_at timestamptz not null default clock_timestamp(),
  call_ended_at timestamptz,
  call_ended_by uuid references auth.users(id),
  updated_at timestamptz not null default clock_timestamp()
);

alter table public.ride_call_state enable row level security;

drop policy if exists "Ride participants can view call state" on public.ride_call_state;
create policy "Ride participants can view call state"
on public.ride_call_state
for select
to authenticated
using (
  exists (
    select 1
    from public.rider_booking rb
    where rb.id = ride_call_state.booking_id
      and (rb.rider_id = (select auth.uid()) or rb.assigned_driver = (select auth.uid()))
  )
);

revoke all on table public.ride_call_state from anon, authenticated;
grant select on table public.ride_call_state to authenticated;

create or replace function public.start_ride_call(p_booking_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rider_id uuid;
  v_assigned_driver uuid;
  v_call_id uuid := gen_random_uuid();
begin
  select rb.rider_id, rb.assigned_driver
  into v_rider_id, v_assigned_driver
  from public.rider_booking rb
  where rb.id = p_booking_id;

  if not found then
    raise exception 'Booking not found';
  end if;

  if auth.uid() is null
    or (auth.uid() <> v_rider_id and auth.uid() is distinct from v_assigned_driver) then
    raise exception 'Not authorized to start a call for this booking';
  end if;

  if v_assigned_driver is null then
    raise exception 'A driver must be assigned before starting a call';
  end if;

  insert into public.ride_call_state (
    booking_id,
    call_id,
    call_started_at,
    call_ended_at,
    call_ended_by,
    updated_at
  )
  values (
    p_booking_id,
    v_call_id,
    clock_timestamp(),
    null,
    null,
    clock_timestamp()
  )
  on conflict (booking_id) do update
  set call_id = excluded.call_id,
      call_started_at = excluded.call_started_at,
      call_ended_at = null,
      call_ended_by = null,
      updated_at = excluded.updated_at;

  return v_call_id;
end;
$$;

create or replace function public.end_ride_call(p_booking_id uuid, p_call_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rider_id uuid;
  v_assigned_driver uuid;
  v_call_ended_at timestamptz;
begin
  select rb.rider_id, rb.assigned_driver
  into v_rider_id, v_assigned_driver
  from public.rider_booking rb
  where rb.id = p_booking_id;

  if not found then
    raise exception 'Booking not found';
  end if;

  if auth.uid() is null
    or (auth.uid() <> v_rider_id and auth.uid() is distinct from v_assigned_driver) then
    raise exception 'Not authorized to end a call for this booking';
  end if;

  update public.ride_call_state
  set call_ended_at = clock_timestamp(),
      call_ended_by = auth.uid(),
      updated_at = clock_timestamp()
  where booking_id = p_booking_id
    and call_id = p_call_id
    and call_ended_at is null
  returning call_ended_at into v_call_ended_at;

  if v_call_ended_at is null then
    raise exception 'Call session not found or already ended';
  end if;

  return v_call_ended_at;
end;
$$;

revoke all on function public.start_ride_call(uuid) from public, anon;
revoke all on function public.end_ride_call(uuid, uuid) from public, anon;
grant execute on function public.start_ride_call(uuid) to authenticated;
grant execute on function public.end_ride_call(uuid, uuid) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'ride_call_state'
  ) then
    alter publication supabase_realtime add table public.ride_call_state;
  end if;
end
$$;