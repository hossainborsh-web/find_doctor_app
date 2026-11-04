-- One-time clean-up of the first (unused, empty) version of the Find Doctor
-- tables, before running schema.sql. Do NOT run this once the app has data.
drop table if exists public.messages, public.conversations, public.slots,
  public.visits, public.chat_requests, public.notifications, public.hr_cases,
  public.inventory, public.posts, public.follows, public.schedules,
  public.demo, public.profiles cascade;
drop function if exists public.enforce_profile_insert() cascade;
drop function if exists public.enforce_profile_update() cascade;
drop function if exists public.enforce_visit_update() cascade;
drop function if exists public.enforce_hr_case_update() cascade;
drop function if exists public.enforce_post_update() cascade;
drop function if exists public.touch_updated_at() cascade;
drop function if exists public.is_gm(), public.is_dm(), public.is_hr(),
  public.is_active(), public.practises(), public.my_email(),
  public.my_hospital(), public.hr_for(text), public.staff_at(text) cascade;
drop policy if exists media_read   on storage.objects;
drop policy if exists media_upload on storage.objects;
drop policy if exists media_delete on storage.objects;
drop policy if exists cert_read    on storage.objects;
drop policy if exists cert_upload  on storage.objects;
drop policy if exists cert_delete  on storage.objects;
