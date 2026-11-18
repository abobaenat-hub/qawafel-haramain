-- 20261118: Media Center V1. Private storage, album library and approval workflow.
-- Apply only once through Supabase migrations.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media-center','media-center',false,209715200,array['image/jpeg','image/png','image/webp','image/heic','video/mp4','video/quicktime','video/webm'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create table if not exists public.media_albums (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 2 and 160),
 description text, trip_label text, event_date date,
 status text not null default 'draft' check(status in ('draft','review','approved','archived')),
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.media_assets (
 id uuid primary key default gen_random_uuid(),
 album_id uuid not null references public.media_albums(id) on delete cascade,
 storage_path text not null unique, original_filename text not null, mime_type text not null,
 file_size bigint not null check(file_size>0 and file_size<=209715200),
 media_type text not null check(media_type in ('image','video')),
 caption text, approval_status text not null default 'pending' check(approval_status in ('pending','approved','rejected')),
 uploaded_by uuid not null references auth.users(id) on delete restrict,
 approved_by uuid references auth.users(id) on delete set null, approved_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists idx_media_albums_created_at on public.media_albums(created_at desc);
create index if not exists idx_media_albums_status on public.media_albums(status);
create index if not exists idx_media_assets_album on public.media_assets(album_id,created_at desc);
create index if not exists idx_media_assets_approval on public.media_assets(approval_status,created_at desc);
alter table public.media_albums enable row level security;
alter table public.media_assets enable row level security;
grant select,insert,update,delete on public.media_albums to authenticated;
grant select,insert,update,delete on public.media_assets to authenticated;

drop policy if exists "media staff read albums" on public.media_albums;
create policy "media staff read albums" on public.media_albums for select to authenticated using(public.has_staff_role(array['media']));
drop policy if exists "media staff create albums" on public.media_albums;
create policy "media staff create albums" on public.media_albums for insert to authenticated with check(public.has_staff_role(array['media']) and created_by=auth.uid());
drop policy if exists "media staff update albums" on public.media_albums;
create policy "media staff update albums" on public.media_albums for update to authenticated using(public.has_staff_role(array['media'])) with check(public.has_staff_role(array['media']));
drop policy if exists "media staff delete albums" on public.media_albums;
create policy "media staff delete albums" on public.media_albums for delete to authenticated using(public.has_staff_role(array['media']));
drop policy if exists "media staff read assets" on public.media_assets;
create policy "media staff read assets" on public.media_assets for select to authenticated using(public.has_staff_role(array['media']));
drop policy if exists "media staff create assets" on public.media_assets;
create policy "media staff create assets" on public.media_assets for insert to authenticated with check(public.has_staff_role(array['media']) and uploaded_by=auth.uid());
drop policy if exists "media staff update assets" on public.media_assets;
create policy "media staff update assets" on public.media_assets for update to authenticated using(public.has_staff_role(array['media'])) with check(public.has_staff_role(array['media']));
drop policy if exists "media staff delete assets" on public.media_assets;
create policy "media staff delete assets" on public.media_assets for delete to authenticated using(public.has_staff_role(array['media']));

drop policy if exists "media staff read media objects" on storage.objects;
create policy "media staff read media objects" on storage.objects for select to authenticated using(bucket_id='media-center' and public.has_staff_role(array['media']));
drop policy if exists "media staff upload media objects" on storage.objects;
create policy "media staff upload media objects" on storage.objects for insert to authenticated with check(bucket_id='media-center' and public.has_staff_role(array['media']));
drop policy if exists "media staff update media objects" on storage.objects;
create policy "media staff update media objects" on storage.objects for update to authenticated using(bucket_id='media-center' and public.has_staff_role(array['media'])) with check(bucket_id='media-center' and public.has_staff_role(array['media']));
drop policy if exists "media staff delete media objects" on storage.objects;
create policy "media staff delete media objects" on storage.objects for delete to authenticated using(bucket_id='media-center' and public.has_staff_role(array['media']));
