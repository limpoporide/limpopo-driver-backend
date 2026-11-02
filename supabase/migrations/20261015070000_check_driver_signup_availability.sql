-- Lets the signup screen check, before an OTP is sent, whether a phone number or
-- email already belongs to another account. Returns only booleans, never user data.
create or replace function public.check_driver_signup_availability(
  p_phone text,
  p_email text default null
)
returns table (
  phone_taken boolean,
  email_taken boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_digits text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_international text;
  v_local text;
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_caller uuid := (select auth.uid());
begin
  if length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_international := '234' || substr(v_digits, 2);
  elsif length(v_digits) = 10 then
    v_international := '234' || v_digits;
  else
    v_international := v_digits;
  end if;

  if left(v_international, 3) = '234' then
    v_local := '0' || substr(v_international, 4);
  else
    v_local := v_international;
  end if;

  phone_taken := v_international <> '' and (
    exists (
      select 1
      from auth.users u
      where regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') = v_international
        and u.id is distinct from v_caller
    )
    or exists (
      select 1
      from public.driver_profile dp
      where dp.phone_num in (v_local, v_international, '+' || v_international)
        and dp.uuid is distinct from v_caller
    )
  );

  email_taken := v_email <> '' and (
    exists (
      select 1
      from auth.users u
      where lower(u.email) = v_email
        and u.id is distinct from v_caller
    )
    or exists (
      select 1
      from public.driver_profile dp
      where lower(dp.email) = v_email
        and dp.uuid is distinct from v_caller
    )
  );

  return next;
end;
$$;

revoke all on function public.check_driver_signup_availability(text, text) from public;
grant execute on function public.check_driver_signup_availability(text, text) to anon, authenticated;
