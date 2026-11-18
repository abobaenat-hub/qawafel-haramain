-- 20261118: Media Center V1.1 security hardening.
-- Only managers and super-admins can approve/reject, edit, or delete media.
drop policy if exists "media staff update albums" on public.media_albums;
create policy "media managers update albums" on public.media_albums for update to authenticated
using(public.has_staff_role(array['super_admin','manager']))
with check(public.has_staff_role(array['super_admin','manager']));
drop policy if exists "media staff delete albums" on public.media_albums;
create policy "media managers delete albums" on public.media_albums for delete to authenticated
using(public.has_staff_role(array['super_admin','manager']));
drop policy if exists "media staff update assets" on public.media_assets;
create policy "media managers update assets" on public.media_assets for update to authenticated
using(public.has_staff_role(array['super_admin','manager']))
with check(public.has_staff_role(array['super_admin','manager']));
drop policy if exists "media staff delete assets" on public.media_assets;
create policy "media managers delete assets" on public.media_assets for delete to authenticated
using(public.has_staff_role(array['super_admin','manager']));
drop policy if exists "media staff update media objects" on storage.objects;
create policy "media managers update media objects" on storage.objects for update to authenticated
using(bucket_id='media-center' and public.has_staff_role(array['super_admin','manager']))
with check(bucket_id='media-center' and public.has_staff_role(array['super_admin','manager']));
drop policy if exists "media staff delete media objects" on storage.objects;
create policy "media managers delete media objects" on storage.objects for delete to authenticated
using(bucket_id='media-center' and public.has_staff_role(array['super_admin','manager']));
