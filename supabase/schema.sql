-- =============================================================================
-- Find Doctor — Supabase backend (database + security rules)
--
-- Run this whole file in Supabase: Dashboard > SQL Editor > New query > Run.
-- Safe to re-run: nothing here deletes data.
--
-- How it fits the app
--   The app keeps each record as a JSON document. Every table stores that document in `doc`, keyed by `id`.
--   A trigger copies the fields the security rules need (emails, role,
--   hospital, status...) out of `doc` into normal columns, and the rules
--   (row-level security + "law" triggers) check those columns.
--
--   App collection -> table
--     users          -> profiles        schedules     -> schedules
--     chatRequests   -> chat_requests   conversations -> conversations
--     notifications  -> notifications   visits        -> visits
--     slots          -> slots           hrCases       -> hr_cases
--     inventory      -> inventory       posts         -> posts
--     follows        -> follows         demo          -> demo
--     media          -> media (photos as shrunk JPEG, base64)
--
-- THE HIRING LAW (enforced here, so editing the app can't get around it):
--   * Sign-up can only make a User (patient), a Student or a New Doctor.
--   * Only Students and New Doctors can ask a hospital for work.
--   * Only HR (a General Manager, or a Doctor Manager of that hospital) can
--     turn a Student / New Doctor into a Doctor, or end a Doctor's work.
--   * Only a General Manager can make or remove a Doctor Manager.
--   * Nobody can change their own role, hospital or status.
--   * The first General Manager is set by hand (see the end of this file).
--
-- Settings this needs in the dashboard:
--   Authentication > Sign In / Providers > Email: enabled,
--   "Confirm email" OFF (the demo accounts use @example.com addresses).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Small JSON helpers
-- -----------------------------------------------------------------------------

-- A field of a document; a missing field counts as JSON null.
create or replace function public.fd_get(d jsonb, k text)
returns jsonb language sql immutable as $$
  select coalesce(d -> k, 'null'::jsonb);
$$;

-- True when every key in ks has the same value in a and b.
create or replace function public.fd_same(a jsonb, b jsonb, ks text[])
returns boolean language sql immutable as $$
  select coalesce(bool_and(public.fd_get(a, k) = public.fd_get(b, k)), true)
  from unnest(ks) k;
$$;

-- True when a and b differ only in the keys listed in ks.
create or replace function public.fd_only_changed(a jsonb, b jsonb, ks text[])
returns boolean language sql immutable as $$
  select (coalesce(a, '{}'::jsonb) - ks) = (coalesce(b, '{}'::jsonb) - ks);
$$;

-- A text field ('' when missing or null).
create or replace function public.fd_text(d jsonb, k text)
returns text language sql immutable as $$
  select coalesce(d ->> k, '');
$$;

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

create table if not exists public.profiles (
  id            text primary key,             -- the sign-in user id
  doc           jsonb not null default '{}'::jsonb,
  email         text not null default '',
  role          text not null default 'patient',
  doctor_kind   text,
  manager_level text,
  hospital      text not null default '',
  status        text not null default 'active',
  updated_at    timestamptz not null default now()
);
create index if not exists profiles_email_idx on public.profiles (email);

create table if not exists public.schedules (
  id         text primary key,                -- doctor's email
  doc        jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_requests (
  id            text primary key,
  doc           jsonb not null default '{}'::jsonb,
  patient_email text not null default '',
  doctor_email  text not null default '',
  updated_at    timestamptz not null default now()
);

create table if not exists public.conversations (
  id           text primary key,
  doc          jsonb not null default '{}'::jsonb,
  type         text not null default '',
  hospital     text not null default '',
  members      text[] not null default '{}',
  leader_email text not null default '',
  updated_at   timestamptz not null default now()
);
create index if not exists conversations_members_idx on public.conversations using gin (members);

create table if not exists public.notifications (
  id         text primary key,
  doc        jsonb not null default '{}'::jsonb,
  recipient  text not null default '',
  updated_at timestamptz not null default now()
);
create index if not exists notifications_recipient_idx on public.notifications (recipient);

create table if not exists public.visits (
  id            text primary key,
  doc           jsonb not null default '{}'::jsonb,
  patient_email text not null default '',
  doctor_email  text not null default '',
  hospital      text not null default '',
  status        text not null default '',
  updated_at    timestamptz not null default now()
);

-- Booked times. The id is made from doctor + time, so the primary key
-- stops two people booking the same time.
create table if not exists public.slots (
  id           text primary key,
  doc          jsonb not null default '{}'::jsonb,
  doctor_email text not null default '',
  owner        text not null default '',
  updated_at   timestamptz not null default now()
);

create table if not exists public.hr_cases (
  id           text primary key,
  doc          jsonb not null default '{}'::jsonb,
  seeker_email text not null default '',
  hospital     text not null default '',
  status       text not null default '',
  updated_at   timestamptz not null default now()
);

create table if not exists public.inventory (
  id         text primary key,
  doc        jsonb not null default '{}'::jsonb,
  hospital   text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.posts (
  id         text primary key,
  doc        jsonb not null default '{}'::jsonb,
  author_uid text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.follows (
  id         text primary key,                -- follower's email
  doc        jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.demo (
  id         text primary key,
  doc        jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.media (
  id         text primary key,
  doc        jsonb not null default '{}'::jsonb,
  owner      text not null default '',
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Copy rule fields out of `doc` (runs first: trigger names start with "a_")
-- -----------------------------------------------------------------------------

create or replace function public.fd_derive()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  if TG_TABLE_NAME = 'profiles' then
    new.email         := lower(public.fd_text(new.doc, 'email'));
    new.role          := coalesce(nullif(new.doc ->> 'role', ''), 'patient');
    new.doctor_kind   := nullif(new.doc ->> 'doctorKind', '');
    new.manager_level := nullif(new.doc ->> 'managerLevel', '');
    new.hospital      := public.fd_text(new.doc, 'hospital');
    new.status        := coalesce(nullif(new.doc ->> 'status', ''), 'active');
  elsif TG_TABLE_NAME = 'chat_requests' then
    new.patient_email := public.fd_text(new.doc, 'patientEmail');
    new.doctor_email  := public.fd_text(new.doc, 'doctorEmail');
  elsif TG_TABLE_NAME = 'conversations' then
    new.type         := public.fd_text(new.doc, 'type');
    new.hospital     := public.fd_text(new.doc, 'hospital');
    new.leader_email := public.fd_text(new.doc, 'leaderEmail');
    new.members      := coalesce(
      (select array_agg(m) from jsonb_array_elements_text(
         case when jsonb_typeof(new.doc -> 'members') = 'array'
              then new.doc -> 'members' else '[]'::jsonb end) m), '{}');
  elsif TG_TABLE_NAME = 'notifications' then
    new.recipient := public.fd_text(new.doc, 'recipient');
  elsif TG_TABLE_NAME = 'visits' then
    new.patient_email := public.fd_text(new.doc, 'patientEmail');
    new.doctor_email  := public.fd_text(new.doc, 'doctorEmail');
    new.hospital      := public.fd_text(new.doc, 'hospital');
    new.status        := public.fd_text(new.doc, 'status');
  elsif TG_TABLE_NAME = 'slots' then
    new.doctor_email := public.fd_text(new.doc, 'doctorEmail');
    new.owner        := public.fd_text(new.doc, 'owner');
  elsif TG_TABLE_NAME = 'hr_cases' then
    new.seeker_email := public.fd_text(new.doc, 'seekerEmail');
    new.hospital     := public.fd_text(new.doc, 'hospital');
    new.status       := public.fd_text(new.doc, 'status');
  elsif TG_TABLE_NAME = 'inventory' then
    new.hospital := public.fd_text(new.doc, 'hospital');
  elsif TG_TABLE_NAME = 'posts' then
    new.author_uid := public.fd_text(new.doc, 'authorUid');
  elsif TG_TABLE_NAME = 'media' then
    new.owner := public.fd_text(new.doc, 'owner');
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['profiles', 'schedules', 'chat_requests', 'conversations',
                           'notifications', 'visits', 'slots', 'hr_cases', 'inventory',
                           'posts', 'follows', 'demo', 'media']
  loop
    execute format('drop trigger if exists a_derive on public.%I', t);
    execute format('create trigger a_derive before insert or update on public.%I
                    for each row execute function public.fd_derive()', t);
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- "Who am I" helpers
-- -----------------------------------------------------------------------------

create or replace function public.my_uid()
returns text language sql stable as $$
  select coalesce(auth.uid()::text, '');
$$;

create or replace function public.my_email()
returns text language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

create or replace function public.me()
returns public.profiles language sql stable security definer set search_path = '' as $$
  select p from public.profiles p where p.id = coalesce(auth.uid()::text, '');
$$;

create or replace function public.my_hospital()
returns text language sql stable as $$
  select coalesce((public.me()).hospital, '');
$$;

create or replace function public.is_active()
returns boolean language sql stable as $$
  select coalesce((public.me()).status = 'active', false);
$$;

create or replace function public.is_gm()
returns boolean language sql stable as $$
  select coalesce((select m.status = 'active'
                          and m.manager_level = 'generalManager'
                          and m.doctor_kind is distinct from 'doctorManager'
                   from (select (public.me()).*) m), false);
$$;

create or replace function public.is_dm()
returns boolean language sql stable as $$
  select coalesce((select m.status = 'active'
                          and (m.doctor_kind = 'doctorManager'
                               or m.manager_level = 'doctorManager')
                          and m.hospital <> ''
                   from (select (public.me()).*) m), false);
$$;

create or replace function public.is_hr()
returns boolean language sql stable as $$
  select public.is_gm() or public.is_dm();
$$;

-- HR for a hospital: any General Manager, or that hospital's Doctor Manager.
create or replace function public.hr_for(h text)
returns boolean language sql stable as $$
  select public.is_gm()
      or (public.is_dm() and lower(public.my_hospital()) = lower(coalesce(h, '')));
$$;

-- Works at a hospital and sees patients.
create or replace function public.practises()
returns boolean language sql stable as $$
  select coalesce((select m.doctor_kind in ('doctor', 'doctorManager')
                          or m.role = 'manager'
                          or m.manager_level is not null
                   from (select (public.me()).*) m), false);
$$;

create or replace function public.staff_at(h text)
returns boolean language sql stable as $$
  select coalesce(h, '') <> ''
     and (public.is_gm()
          or (public.is_active() and public.practises()
              and public.my_hospital() = h));
$$;

-- -----------------------------------------------------------------------------
-- Reading and changing documents from the app
-- -----------------------------------------------------------------------------

create or replace function public.fd_table(p_table text)
returns text language plpgsql immutable as $$
begin
  if p_table not in ('profiles', 'schedules', 'chat_requests', 'conversations',
                     'notifications', 'visits', 'slots', 'hr_cases', 'inventory',
                     'posts', 'follows', 'demo', 'media') then
    raise exception 'Unknown table %', p_table using errcode = '22023';
  end if;
  return p_table;
end $$;

-- Writes a whole document: updates it if it exists, otherwise creates it.
-- Runs with the caller's rights, so every security rule applies.
create or replace function public.fd_set(p_table text, p_id text, p_doc jsonb)
returns void language plpgsql as $$
declare n int;
begin
  execute format('update public.%I set doc = $2 where id = $1',
                 public.fd_table(p_table)) using p_id, p_doc;
  get diagnostics n = row_count;
  if n = 0 then
    execute format('insert into public.%I (id, doc) values ($1, $2)',
                   p_table) using p_id, p_doc;
  end if;
end $$;

-- Changes part of a document. p_ops is a list of
--   {"op": "set",    "path": ["a", "b"], "value": ...}
--   {"op": "delete", "path": [...]}
--   {"op": "union",  "path": [...], "value": [...]}   add missing items
--   {"op": "remove", "path": [...], "value": [...]}   take items out
-- so two people changing one document at once don't undo each other.
create or replace function public.fd_patch(p_table text, p_id text, p_ops jsonb)
returns void language plpgsql as $$
declare
  d      jsonb;
  op     jsonb;
  path   text[];
  cur    jsonb;
  item   jsonb;
  i      int;
begin
  execute format('select doc from public.%I where id = $1 for update',
                 public.fd_table(p_table)) into d using p_id;
  if d is null then
    raise exception 'Document %/% not found', p_table, p_id using errcode = 'P0002';
  end if;
  for op in select value from jsonb_array_elements(p_ops) loop
    path := array(select jsonb_array_elements_text(op -> 'path'));
    -- make sure the parent objects exist
    for i in 1 .. coalesce(array_length(path, 1), 0) - 1 loop
      if jsonb_typeof(d #> path[1:i]) is distinct from 'object' then
        d := jsonb_set(d, path[1:i], '{}'::jsonb, true);
      end if;
    end loop;
    if op ->> 'op' = 'set' then
      d := jsonb_set(d, path, coalesce(op -> 'value', 'null'::jsonb), true);
    elsif op ->> 'op' = 'delete' then
      d := d #- path;
    elsif op ->> 'op' = 'union' then
      cur := case when jsonb_typeof(d #> path) = 'array' then d #> path else '[]'::jsonb end;
      for item in select value from jsonb_array_elements(op -> 'value') loop
        if not exists (select 1 from jsonb_array_elements(cur) e where e = item) then
          cur := cur || jsonb_build_array(item);
        end if;
      end loop;
      d := jsonb_set(d, path, cur, true);
    elsif op ->> 'op' = 'remove' then
      cur := case when jsonb_typeof(d #> path) = 'array' then d #> path else '[]'::jsonb end;
      cur := coalesce((select jsonb_agg(e) from jsonb_array_elements(cur) e
                       where not exists (select 1 from jsonb_array_elements(op -> 'value') r
                                         where r = e)), '[]'::jsonb);
      d := jsonb_set(d, path, cur, true);
    end if;
  end loop;
  execute format('update public.%I set doc = $2 where id = $1', p_table) using p_id, d;
end $$;

-- -----------------------------------------------------------------------------
-- New sign-ups: a profile is made from the sign-up details, with the law
-- applied (only User, Student or New Doctor; no hospital; active).
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  d    jsonb := coalesce(new.raw_user_meta_data -> 'doc', '{}'::jsonb);
  kind text  := d ->> 'doctorKind';
begin
  if jsonb_typeof(d) <> 'object' then d := '{}'::jsonb; end if;
  if (d ->> 'role') = 'doctor' and kind in ('student', 'newDoctor') then
    d := d || jsonb_build_object('role', 'doctor', 'doctorKind', kind);
  else
    d := d || jsonb_build_object('role', 'patient', 'doctorKind', null);
  end if;
  d := d || jsonb_build_object(
    'id', new.id::text,
    'email', lower(new.email),
    'managerLevel', null,
    'hospital', '',
    'status', 'active',
    'hiredBy', '',
    'hiredAt', null,
    'reviewedBy', null,
    'reviewedAt', null,
    'fullName', coalesce(nullif(d ->> 'fullName', ''), split_part(new.email, '@', 1)),
    -- to_jsonb(now()) is already a JSON string; (::text would add quotes).
    'createdAt', coalesce(nullif(d -> 'createdAt', 'null'::jsonb), to_jsonb(now())));
  insert into public.profiles (id, doc) values (new.id::text, d)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- PROFILES: the hiring law
-- auth.uid() is null only for admins (SQL editor, service key, sign-up trigger).
-- -----------------------------------------------------------------------------
create or replace function public.fd_profiles_law()
returns trigger language plpgsql as $$
declare
  a jsonb := new.doc;
  b jsonb := case when TG_OP = 'UPDATE' then old.doc else '{}'::jsonb end;
  personal text[] := array['fullName', 'email', 'birthday', 'specialty', 'university',
                           'graduationYear', 'certificatePath', 'createdAt', 'status'];
begin
  if auth.uid() is null then return new; end if;

  if TG_OP = 'INSERT' then
    if new.id = public.my_uid()
       and new.email = public.my_email()
       and new.manager_level is null
       and new.status = 'active'
       and new.hospital = ''
       and public.fd_text(a, 'hiredBy') = ''
       and ((new.role = 'patient' and new.doctor_kind is null)
            or (new.role = 'doctor' and new.doctor_kind in ('student', 'newDoctor'))) then
      return new;
    end if;
    raise exception 'Sign-up can only create a User, a Student or a New Doctor.'
      using errcode = '42501';
  end if;

  if new.id <> old.id then
    raise exception 'A profile id cannot change.' using errcode = '42501';
  end if;

  -- 1) Your own profile: everything except role, hospital, status and hiring.
  if old.id = public.my_uid() then
    if public.fd_same(a, b, array['role', 'doctorKind', 'managerLevel', 'hospital',
                                  'status', 'email', 'hiredBy', 'hiredAt',
                                  'reviewedBy', 'reviewedAt']) then
      return new;
    end if;
    raise exception 'Nobody can change their own role, hospital or status.'
      using errcode = '42501';
  end if;

  -- 2) HR hires: a Student / New Doctor becomes a Doctor at a hospital.
  if old.doctor_kind in ('student', 'newDoctor')
     and old.status = 'active'
     and new.role = 'doctor'
     and new.doctor_kind = 'doctor'
     and new.manager_level is null
     and new.hospital <> ''
     and public.hr_for(new.hospital)
     and public.fd_same(a, b, personal) then
    return new;
  end if;

  -- 3) HR ends a Doctor's work: they become a New Doctor again.
  --    Doctor Managers can only be released by a General Manager.
  if old.doctor_kind in ('doctor', 'doctorManager')
     and old.hospital <> ''
     and public.hr_for(old.hospital)
     and (old.doctor_kind = 'doctor' or public.is_gm())
     and new.role = 'doctor'
     and new.doctor_kind = 'newDoctor'
     and new.manager_level is null
     and new.hospital = ''
     and public.fd_same(a, b, personal) then
    return new;
  end if;

  -- 4) Only a General Manager gives or removes Doctor Manager.
  if public.is_gm()
     and old.doctor_kind in ('doctor', 'doctorManager')
     and old.hospital <> ''
     and new.role = 'doctor'
     and new.doctor_kind in ('doctor', 'doctorManager')
     and new.manager_level is null
     and new.hospital = old.hospital
     and public.fd_only_changed(a, b, array['role', 'doctorKind', 'managerLevel']) then
    return new;
  end if;

  raise exception 'This change is not allowed by the hiring rules.' using errcode = '42501';
end $$;

drop trigger if exists b_law on public.profiles;
create trigger b_law before insert or update on public.profiles
  for each row execute function public.fd_profiles_law();

drop policy if exists profiles_read   on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
create policy profiles_read   on public.profiles for select to authenticated using (true);
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = public.my_uid());
create policy profiles_update on public.profiles for update to authenticated
  using (true) with check (true);          -- decided by the b_law trigger

-- -----------------------------------------------------------------------------
-- SCHEDULES: everyone reads; doctors write their own
-- -----------------------------------------------------------------------------
drop policy if exists schedules_read  on public.schedules;
drop policy if exists schedules_write on public.schedules;
create policy schedules_read  on public.schedules for select to authenticated using (true);
create policy schedules_write on public.schedules for all to authenticated
  using (id = public.my_email()) with check (id = public.my_email());

-- -----------------------------------------------------------------------------
-- CHAT REQUESTS
-- -----------------------------------------------------------------------------
drop policy if exists chat_requests_read   on public.chat_requests;
drop policy if exists chat_requests_create on public.chat_requests;
drop policy if exists chat_requests_change on public.chat_requests;
drop policy if exists chat_requests_delete on public.chat_requests;
create policy chat_requests_read on public.chat_requests for select to authenticated
  using (patient_email = public.my_email() or doctor_email = public.my_email());
create policy chat_requests_create on public.chat_requests for insert to authenticated
  with check (patient_email = public.my_email());
-- After a change you must still be the patient or the doctor (no handing a
-- request over to other people).
create policy chat_requests_change on public.chat_requests for update to authenticated
  using (patient_email = public.my_email() or doctor_email = public.my_email())
  with check (patient_email = public.my_email() or doctor_email = public.my_email());
create policy chat_requests_delete on public.chat_requests for delete to authenticated
  using (patient_email = public.my_email() or doctor_email = public.my_email());

-- -----------------------------------------------------------------------------
-- CONVERSATIONS (messages are inside the document)
-- -----------------------------------------------------------------------------
drop policy if exists conversations_read   on public.conversations;
drop policy if exists conversations_create on public.conversations;
drop policy if exists conversations_change on public.conversations;
drop policy if exists conversations_delete on public.conversations;
create policy conversations_read on public.conversations for select to authenticated
  using (public.my_email() = any (members) or type = 'community'
         or (type = 'hospital' and public.staff_at(hospital)));
create policy conversations_create on public.conversations for insert to authenticated
  with check (public.my_email() = any (members) or type = 'community'
              or (type = 'hospital' and public.staff_at(hospital)));
create policy conversations_change on public.conversations for update to authenticated
  using (public.my_email() = any (members) or type = 'community'
         or (type = 'hospital' and public.staff_at(hospital)))
  with check (true);
create policy conversations_delete on public.conversations for delete to authenticated
  using (public.my_email() = any (members) or leader_email = public.my_email()
         or public.is_gm());

-- -----------------------------------------------------------------------------
-- NOTIFICATIONS
-- -----------------------------------------------------------------------------
drop policy if exists notifications_read   on public.notifications;
drop policy if exists notifications_create on public.notifications;
drop policy if exists notifications_change on public.notifications;
drop policy if exists notifications_delete on public.notifications;
create policy notifications_read on public.notifications for select to authenticated
  using (recipient = public.my_email());
create policy notifications_create on public.notifications for insert to authenticated
  with check (recipient <> '');
create policy notifications_change on public.notifications for update to authenticated
  using (recipient = public.my_email()) with check (recipient = public.my_email());
create policy notifications_delete on public.notifications for delete to authenticated
  using (recipient = public.my_email());

-- -----------------------------------------------------------------------------
-- VISITS: users book; only the doctor (or HR) confirms or completes
-- -----------------------------------------------------------------------------
create or replace function public.fd_visits_law()
returns trigger language plpgsql as $$
begin
  if auth.uid() is null then return new; end if;
  if new.patient_email is distinct from old.patient_email
  or new.doctor_email is distinct from old.doctor_email then
    raise exception 'A visit''s patient and doctor cannot change.' using errcode = '42501';
  end if;
  if (old.patient_email = public.my_email() and new.status in ('requested', 'cancelled'))
     or old.doctor_email = public.my_email()
     or public.hr_for(old.hospital) then
    return new;
  end if;
  raise exception 'Only the doctor or HR can confirm or complete a visit.' using errcode = '42501';
end $$;
drop trigger if exists b_law on public.visits;
create trigger b_law before update on public.visits
  for each row execute function public.fd_visits_law();

drop policy if exists visits_read   on public.visits;
drop policy if exists visits_create on public.visits;
drop policy if exists visits_change on public.visits;
drop policy if exists visits_delete on public.visits;
create policy visits_read on public.visits for select to authenticated
  using (patient_email = public.my_email() or doctor_email = public.my_email()
         or public.is_gm()
         or (public.is_dm() and hospital = public.my_hospital()));
create policy visits_create on public.visits for insert to authenticated
  with check (patient_email = public.my_email() and status = 'requested');
create policy visits_change on public.visits for update to authenticated
  using (patient_email = public.my_email() or doctor_email = public.my_email()
         or public.hr_for(hospital))
  with check (true);
create policy visits_delete on public.visits for delete to authenticated
  using (patient_email = public.my_email() or doctor_email = public.my_email()
         or public.hr_for(hospital));

-- -----------------------------------------------------------------------------
-- SLOTS
-- -----------------------------------------------------------------------------
drop policy if exists slots_read   on public.slots;
drop policy if exists slots_create on public.slots;
drop policy if exists slots_delete on public.slots;
create policy slots_read   on public.slots for select to authenticated using (true);
create policy slots_create on public.slots for insert to authenticated
  with check (owner = public.my_uid());
create policy slots_delete on public.slots for delete to authenticated
  using (owner = public.my_uid() or doctor_email = public.my_email() or public.is_hr());

-- -----------------------------------------------------------------------------
-- HR CASES (hiring)
-- -----------------------------------------------------------------------------
create or replace function public.fd_hr_cases_law()
returns trigger language plpgsql as $$
begin
  if auth.uid() is null then return new; end if;
  if new.seeker_email is distinct from old.seeker_email
  or new.hospital is distinct from old.hospital then
    raise exception 'A request''s person and hospital cannot change.' using errcode = '42501';
  end if;
  -- The job seeker: accept an offer, withdraw, or close their own request.
  if old.seeker_email = public.my_email() then
    if new.status in ('requested', 'scheduled', 'declined', 'withdrawn', 'closed') then
      return new;
    end if;
    raise exception 'You cannot hire yourself.' using errcode = '42501';
  end if;
  -- HR of that hospital: accept, set the join day, decline, hire.
  if public.hr_for(old.hospital) then return new; end if;
  -- Any HR may close a case (status and note only).
  if public.is_hr() and new.status = 'closed'
     and public.fd_only_changed(new.doc, old.doc, array['status', 'note', 'updatedAt']) then
    return new;
  end if;
  raise exception 'Only HR of this hospital can answer this request.' using errcode = '42501';
end $$;
drop trigger if exists b_law on public.hr_cases;
create trigger b_law before update on public.hr_cases
  for each row execute function public.fd_hr_cases_law();

drop policy if exists hr_cases_read   on public.hr_cases;
drop policy if exists hr_cases_create on public.hr_cases;
drop policy if exists hr_cases_change on public.hr_cases;
create policy hr_cases_read on public.hr_cases for select to authenticated
  using (seeker_email = public.my_email() or public.is_hr());
create policy hr_cases_create on public.hr_cases for insert to authenticated
  with check (
    -- Only Students and New Doctors can ask to work at a hospital.
    (seeker_email = public.my_email()
       and status = 'requested'
       and (public.me()).doctor_kind in ('student', 'newDoctor'))
    -- HR can offer a job to someone else.
    or (status = 'offered'
        and seeker_email <> public.my_email()
        and public.hr_for(hospital)));
create policy hr_cases_change on public.hr_cases for update to authenticated
  using (seeker_email = public.my_email() or public.is_hr()) with check (true);
-- No delete: hiring history is kept.

-- -----------------------------------------------------------------------------
-- INVENTORY (per hospital)
-- -----------------------------------------------------------------------------
drop policy if exists inventory_read   on public.inventory;
drop policy if exists inventory_create on public.inventory;
drop policy if exists inventory_change on public.inventory;
drop policy if exists inventory_delete on public.inventory;
create policy inventory_read on public.inventory for select to authenticated
  using (public.is_gm()
         or (hospital = public.my_hospital() and public.is_active() and public.practises()));
create policy inventory_create on public.inventory for insert to authenticated
  with check (public.staff_at(hospital));
create policy inventory_change on public.inventory for update to authenticated
  using (public.staff_at(hospital)) with check (public.staff_at(hospital));
create policy inventory_delete on public.inventory for delete to authenticated
  using (public.staff_at(hospital));

-- -----------------------------------------------------------------------------
-- POSTS: authors edit their own; others only like, save, view or comment
-- -----------------------------------------------------------------------------
create or replace function public.fd_posts_law()
returns trigger language plpgsql as $$
begin
  if auth.uid() is null then return new; end if;
  if (old.author_uid = public.my_uid() and new.author_uid = old.author_uid)
     or public.fd_only_changed(new.doc, old.doc,
                               array['likedBy', 'savedBy', 'viewedBy', 'comments']) then
    return new;
  end if;
  raise exception 'You can only like, save or comment on someone else''s post.'
    using errcode = '42501';
end $$;
drop trigger if exists b_law on public.posts;
create trigger b_law before update on public.posts
  for each row execute function public.fd_posts_law();

drop policy if exists posts_read   on public.posts;
drop policy if exists posts_create on public.posts;
drop policy if exists posts_change on public.posts;
drop policy if exists posts_delete on public.posts;
create policy posts_read on public.posts for select to authenticated using (true);
create policy posts_create on public.posts for insert to authenticated
  with check (author_uid = public.my_uid()
              or (author_uid = '' and (id like 'seed\_%' or id like 'reel\_%')));
create policy posts_change on public.posts for update to authenticated
  using (true) with check (true);          -- decided by the b_law trigger
create policy posts_delete on public.posts for delete to authenticated
  using ((author_uid <> '' and author_uid = public.my_uid()) or public.is_gm());

-- -----------------------------------------------------------------------------
-- FOLLOWS, DEMO, MEDIA
-- -----------------------------------------------------------------------------
drop policy if exists follows_read  on public.follows;
drop policy if exists follows_write on public.follows;
create policy follows_read  on public.follows for select to authenticated using (true);
create policy follows_write on public.follows for all to authenticated
  using (id = public.my_email()) with check (id = public.my_email());

drop policy if exists demo_gm on public.demo;
create policy demo_gm on public.demo for all to authenticated
  using (public.is_gm()) with check (public.is_gm());

drop policy if exists media_read   on public.media;
drop policy if exists media_create on public.media;
drop policy if exists media_delete on public.media;
create policy media_read on public.media for select to authenticated using (true);
create policy media_create on public.media for insert to authenticated
  with check (owner = public.my_uid()
              and length(public.fd_text(doc, 'data')) < 1000000);
create policy media_delete on public.media for delete to authenticated
  using (owner = public.my_uid());

-- -----------------------------------------------------------------------------
-- Access for signed-in app users (row-level security above still applies)
-- -----------------------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on function public.fd_set(text, text, jsonb),
                          public.fd_patch(text, text, jsonb) to authenticated;
revoke all on all tables in schema public from anon;

-- =============================================================================
-- FIRST GENERAL MANAGER — run once by hand, after you sign up in the app:
--
--   update public.profiles
--      set doc = doc || '{"role": "manager", "managerLevel": "generalManager",
--                         "doctorKind": null}'::jsonb
--    where email = 'your-email@example.com';
-- =============================================================================
