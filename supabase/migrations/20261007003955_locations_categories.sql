-- 0003: locations y categories (catalogos administrables).

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.locations (id) on delete restrict,
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  kind public.location_kind not null,
  lat numeric(9, 6) check (lat between -90 and 90),
  lng numeric(9, 6) check (lng between -180 and 180),
  is_active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index locations_parent_id_idx on public.locations (parent_id);
create index locations_active_kind_idx on public.locations (kind, sort_order) where is_active;

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories (id) on delete restrict,
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  icon text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index categories_parent_id_idx on public.categories (parent_id);
create index categories_active_sort_idx on public.categories (sort_order) where is_active;

create trigger locations_set_updated_at
  before update on public.locations
  for each row execute function public.set_updated_at();

create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

alter table public.locations enable row level security;
alter table public.categories enable row level security;

-- Lectura publica solo de activos; admin ve todo.
create policy locations_select on public.locations
  for select to anon, authenticated
  using (is_active or public.is_admin());

create policy categories_select on public.categories
  for select to anon, authenticated
  using (is_active or public.is_admin());

-- Escritura solo admin.
create policy locations_admin_write on public.locations
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy categories_admin_write on public.categories
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

revoke insert, update, delete, truncate on public.locations, public.categories from anon;
