-- =====================================================================
-- Partner-Portal: Unterlagen (Präsentationen, Skripte, Dokumente)
-- Ergänzung zu setup.sql – idempotent.
-- =====================================================================

create table if not exists public.materials (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  category        text not null default 'Präsentationen',
  file_path       text unique not null,
  file_name       text not null,
  mime            text,
  size_bytes      bigint,
  allow_download  boolean not null default true,
  visible_to      text[],            -- null = alle Partner, sonst Liste von E-Mail-Adressen (klein)
  active          boolean not null default true,
  sort_order      int not null default 100,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Nutzungszählung: gleiche Tabelle wie bei den Rechnern
alter table public.usage_events add column if not exists material_id uuid references public.materials on delete cascade;
alter table public.usage_events add column if not exists action text not null default 'open';
create index if not exists usage_events_material_idx on public.usage_events (material_id);

-- Darf der angemeldete Nutzer diese Unterlage sehen?
create or replace function public.can_see_material(m public.materials) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or (public.is_member() and m.active and (m.visible_to is null or public.my_email() = any (m.visible_to)));
$$;

alter table public.materials enable row level security;
drop policy if exists materials_select on public.materials;
create policy materials_select on public.materials
  for select using (public.can_see_material(materials));
drop policy if exists materials_admin on public.materials;
create policy materials_admin on public.materials
  for all using (public.is_admin()) with check (public.is_admin());

-- Privater Speicher, max. 50 MB pro Datei
insert into storage.buckets (id, name, public, file_size_limit)
values ('unterlagen', 'unterlagen', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = 52428800;

-- Lesen nur, wenn die zugehörige Unterlage für den Nutzer freigegeben ist
create or replace function public.can_read_material_file(path text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or exists (select 1 from materials m where m.file_path = path and public.can_see_material(m));
$$;

drop policy if exists unterlagen_read on storage.objects;
create policy unterlagen_read on storage.objects
  for select using (bucket_id = 'unterlagen' and public.can_read_material_file(name));
drop policy if exists unterlagen_admin_insert on storage.objects;
create policy unterlagen_admin_insert on storage.objects
  for insert with check (bucket_id = 'unterlagen' and public.is_admin());
drop policy if exists unterlagen_admin_update on storage.objects;
create policy unterlagen_admin_update on storage.objects
  for update using (bucket_id = 'unterlagen' and public.is_admin());
drop policy if exists unterlagen_admin_delete on storage.objects;
create policy unterlagen_admin_delete on storage.objects
  for delete using (bucket_id = 'unterlagen' and public.is_admin());

revoke execute on function public.can_see_material(public.materials) from public, anon;
revoke execute on function public.can_read_material_file(text) from public, anon;
grant execute on function public.can_see_material(public.materials) to authenticated;
grant execute on function public.can_read_material_file(text) to authenticated;

-- =====================================================================
-- Favoriten und „Zuletzt genutzt“
-- =====================================================================
create table if not exists public.favorites (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  kind text not null check (kind in ('calc','doc')),
  item_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, kind, item_id)
);
alter table public.favorites enable row level security;
drop policy if exists favorites_own on public.favorites;
create policy favorites_own on public.favorites for all
  using (user_id = auth.uid() and public.is_member())
  with check (user_id = auth.uid() and public.is_member());
drop policy if exists usage_select_own on public.usage_events;
create policy usage_select_own on public.usage_events for select using (user_id = auth.uid());
create index if not exists usage_events_user_idx on public.usage_events (user_id, created_at desc);
