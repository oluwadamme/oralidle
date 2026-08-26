-- Name and email in one place, without duplicating the address.
--
-- `auth.users.email` is the authoritative copy: Supabase writes it only after
-- the OTP is verified, so a column on `profiles` would be an unverified second
-- copy that drifts the moment someone changes their address. Joining costs
-- nothing here and cannot go stale.
--
-- Lives in `analytics` like the other views, so the publishable key cannot
-- reach it — this is the one view that exposes email addresses.

create view analytics.v_users as
select
  p.id,
  p.display_name,
  u.email,
  u.is_anonymous,
  u.email_confirmed_at is not null as email_verified,
  p.created_at,
  u.last_sign_in_at,
  (select count(*) from public.sessions s where s.user_id = p.id)   as sessions,
  (select count(*) from public.interviews i where i.user_id = p.id) as interviews,
  greatest(
    (select max(s.recorded_at) from public.sessions s where s.user_id = p.id),
    (select max(i.recorded_at) from public.interviews i where i.user_id = p.id)
  ) as last_activity_at
from public.profiles p
join auth.users u on u.id = p.id;

-- How many anonymous users ever get as far as adding an email. The number that
-- decides whether the twice-only prompt is pitched right.
create view analytics.v_linked_rate as
select
  count(*)                                          as users,
  count(*) filter (where not is_anonymous)          as linked,
  round(
    100.0 * count(*) filter (where not is_anonymous) / nullif(count(*), 0),
    1
  ) as linked_pct
from analytics.v_users;
