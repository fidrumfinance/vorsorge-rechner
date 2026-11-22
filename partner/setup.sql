-- =====================================================================
-- Partner-Portal Rechner-Bibliothek: Supabase-Setup
-- Einmalig im Supabase SQL-Editor ausführen (idempotent).
-- =====================================================================

-- ---------- Tabellen ----------
create table if not exists public.invites (
  email        text primary key check (email = lower(email)),
  full_name    text,
  company      text,
  role         text not null default 'partner' check (role in ('partner','admin')),
  invited_at   timestamptz not null default now(),
  invited_by   uuid references auth.users on delete set null,
  accepted_at  timestamptz
);

create table if not exists public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  email       text not null,
  full_name   text,
  company     text,
  role        text not null default 'partner' check (role in ('partner','admin')),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  last_seen   timestamptz
);

create table if not exists public.calculators (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,
  title        text not null,
  description  text,
  category     text not null default 'Vermögen aufbauen',
  file_path    text not null,
  active       boolean not null default true,
  sort_order   int not null default 100,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.usage_events (
  id             bigserial primary key,
  user_id        uuid references auth.users on delete set null,
  calculator_id  uuid references public.calculators on delete cascade,
  created_at     timestamptz not null default now()
);
create index if not exists usage_events_created_idx on public.usage_events (created_at desc);

-- ---------- Hilfsfunktionen ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin' and active);
$$;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and active);
$$;

create or replace function public.touch_last_seen() returns void
language sql security definer set search_path = public as $$
  update profiles set last_seen = now() where id = auth.uid();
$$;

-- ---------- Nur Eingeladene dürfen ein Konto anlegen ----------
create or replace function public.enforce_invite() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from invites where email = lower(new.email)) then
    raise exception 'Diese E-Mail-Adresse ist nicht eingeladen.';
  end if;
  return new;
end $$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare inv invites%rowtype;
begin
  select * into inv from invites where email = lower(new.email);
  insert into profiles (id, email, full_name, company, role)
  values (new.id, lower(new.email), inv.full_name, inv.company, coalesce(inv.role, 'partner'))
  on conflict (id) do nothing;
  update invites set accepted_at = now() where email = lower(new.email);
  return new;
end $$;

drop trigger if exists enforce_invite_before_signup on auth.users;
create trigger enforce_invite_before_signup
  before insert on auth.users for each row execute function public.enforce_invite();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- ---------- Zugriffsregeln (Row Level Security) ----------
alter table public.invites      enable row level security;
alter table public.profiles     enable row level security;
alter table public.calculators  enable row level security;
alter table public.usage_events enable row level security;

drop policy if exists invites_admin on public.invites;
create policy invites_admin on public.invites
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles
  for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists profiles_admin_delete on public.profiles;
create policy profiles_admin_delete on public.profiles
  for delete using (public.is_admin());

drop policy if exists calculators_select on public.calculators;
create policy calculators_select on public.calculators
  for select using (public.is_member() and (active or public.is_admin()));
drop policy if exists calculators_admin on public.calculators;
create policy calculators_admin on public.calculators
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists usage_insert_own on public.usage_events;
create policy usage_insert_own on public.usage_events
  for insert with check (user_id = auth.uid() and public.is_member());
drop policy if exists usage_admin_select on public.usage_events;
create policy usage_admin_select on public.usage_events
  for select using (public.is_admin());

-- ---------- Privater Speicher für die Rechner-Dateien ----------
insert into storage.buckets (id, name, public)
values ('rechner', 'rechner', false)
on conflict (id) do update set public = false;

drop policy if exists rechner_read on storage.objects;
create policy rechner_read on storage.objects
  for select using (bucket_id = 'rechner' and public.is_member());
drop policy if exists rechner_admin_insert on storage.objects;
create policy rechner_admin_insert on storage.objects
  for insert with check (bucket_id = 'rechner' and public.is_admin());
drop policy if exists rechner_admin_update on storage.objects;
create policy rechner_admin_update on storage.objects
  for update using (bucket_id = 'rechner' and public.is_admin());
drop policy if exists rechner_admin_delete on storage.objects;
create policy rechner_admin_delete on storage.objects
  for delete using (bucket_id = 'rechner' and public.is_admin());

-- ---------- Erster Admin ----------
-- E-Mail-Adresse des Admins (Kleinbuchstaben):
insert into public.invites (email, full_name, company, role)
values ('info@fidrumfinance.com', 'Daniel Dinh', 'Fidrum Finance', 'admin')
on conflict (email) do update set role = 'admin';
-- Falls dieses Konto schon existiert, zum Admin machen:
update public.profiles set role = 'admin', active = true
where email = 'info@fidrumfinance.com';

-- ---------- Interne Funktionen nicht von außen aufrufbar ----------
revoke execute on function public.enforce_invite() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.touch_last_seen() from public, anon;
grant execute on function public.touch_last_seen() to authenticated;
