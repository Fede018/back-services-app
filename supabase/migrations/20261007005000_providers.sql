-- 0005: providers y tablas hijas, constraints, indices, search_vector y RLS.

create table public.providers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  business_name text not null check (char_length(business_name) between 2 and 120),
  provider_type public.provider_type not null,
  description text check (char_length(description) <= 2000),
  whatsapp text check (whatsapp ~ '^\+[1-9][0-9]{7,14}$'),
  phone text check (phone ~ '^\+?[0-9 ()-]{6,20}$'),
  location_id uuid references public.locations (id) on delete restrict,
  offers_home_visit boolean not null default false,
  offers_delivery boolean not null default false,
  status public.provider_status not null default 'draft',
  verified_at timestamptz,
  is_demo boolean not null default false,
  published_at timestamptz,
  search_vector tsvector,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint providers_published_needs_contact check (status <> 'published' or whatsapp is not null)
);

create index providers_status_location_idx on public.providers (status, location_id);
create index providers_owner_id_idx on public.providers (owner_id);
create index providers_search_vector_idx on public.providers using gin (search_vector);
create index providers_business_name_trgm_idx on public.providers using gin (business_name extensions.gin_trgm_ops);

create table public.provider_categories (
  provider_id uuid not null references public.providers (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete restrict,
  primary key (provider_id, category_id)
);
create index provider_categories_category_id_idx on public.provider_categories (category_id);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  description text check (char_length(description) <= 1000),
  price_from numeric(12, 2) check (price_from >= 0),
  price_to numeric(12, 2) check (price_to >= 0),
  currency char(3) not null default 'ARS' check (currency = 'ARS'),
  price_unit text check (char_length(price_unit) <= 40),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint services_price_range check (price_to is null or (price_from is not null and price_to >= price_from))
);
create index services_provider_id_idx on public.services (provider_id);

create table public.provider_coverage_areas (
  provider_id uuid not null references public.providers (id) on delete cascade,
  location_id uuid not null references public.locations (id) on delete restrict,
  primary key (provider_id, location_id)
);
create index provider_coverage_areas_location_id_idx on public.provider_coverage_areas (location_id);

create table public.business_hours (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  opens_at time not null,
  closes_at time not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_hours_order check (closes_at > opens_at)
);
create index business_hours_provider_weekday_idx on public.business_hours (provider_id, weekday);

create table public.availability_status (
  provider_id uuid primary key references public.providers (id) on delete cascade,
  state public.availability_state not null default 'unavailable',
  note text check (char_length(note) <= 200),
  updated_at timestamptz not null default now()
);

create table public.provider_images (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete cascade,
  storage_path text not null,
  alt text check (char_length(alt) <= 200),
  sort_order integer not null default 0,
  is_cover boolean not null default false,
  created_at timestamptz not null default now()
);
create index provider_images_provider_id_idx on public.provider_images (provider_id, sort_order);
create unique index provider_images_one_cover_idx on public.provider_images (provider_id) where is_cover;

-- updated_at
create trigger services_set_updated_at before update on public.services
  for each row execute function public.set_updated_at();
create trigger business_hours_set_updated_at before update on public.business_hours
  for each row execute function public.set_updated_at();
create trigger availability_status_set_updated_at before update on public.availability_status
  for each row execute function public.set_updated_at();

-- search_vector: nombre (A), descripcion (B), categorias (C). Config spanish + unaccent.
create function public.compute_provider_search_vector(p_id uuid, p_name text, p_description text)
returns tsvector
language sql
stable
set search_path = ''
as $$
  select
    setweight(to_tsvector('spanish', extensions.unaccent(coalesce(p_name, ''))), 'A') ||
    setweight(to_tsvector('spanish', extensions.unaccent(coalesce(p_description, ''))), 'B') ||
    setweight(to_tsvector('spanish', extensions.unaccent(coalesce(
      (select string_agg(c.name, ' ')
         from public.provider_categories pc
         join public.categories c on c.id = pc.category_id
        where pc.provider_id = p_id), ''))), 'C');
$$;

-- Guardas del propietario. Los triggers BEFORE corren en orden alfabetico: a_guard, b_search, c_updated_at.
create function public.providers_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin') or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.owner_id is distinct from (select auth.uid()) then
      raise exception 'owner_id debe ser el usuario actual' using errcode = '42501';
    end if;
    if new.status <> 'draft' or new.verified_at is not null or new.is_demo or new.published_at is not null then
      raise exception 'alta solo permitida como borrador' using errcode = '42501';
    end if;
    return new;
  end if;

  if new.owner_id is distinct from old.owner_id
     or new.verified_at is distinct from old.verified_at
     or new.is_demo is distinct from old.is_demo
     or new.published_at is distinct from old.published_at
     or new.search_vector is distinct from old.search_vector then
    raise exception 'campo protegido' using errcode = '42501';
  end if;

  if new.status is distinct from old.status
     and (old.status, new.status) not in (('draft', 'pending_review'), ('pending_review', 'draft')) then
    raise exception 'transicion de estado no permitida' using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger providers_a_guard
  before insert or update on public.providers
  for each row execute function public.providers_guard();

create function public.providers_set_search_vector()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_vector := public.compute_provider_search_vector(new.id, new.business_name, new.description);
  return new;
end;
$$;

create trigger providers_b_search
  before insert or update of business_name, description on public.providers
  for each row execute function public.providers_set_search_vector();

create trigger providers_c_updated_at
  before update on public.providers
  for each row execute function public.set_updated_at();

-- Refresca search_vector cuando cambian las categorias del prestador (corre como duena: postgres).
create function public.provider_categories_refresh_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := coalesce(new.provider_id, old.provider_id);
begin
  update public.providers p
     set search_vector = public.compute_provider_search_vector(p.id, p.business_name, p.description)
   where p.id = v_id;
  return null;
end;
$$;

create trigger provider_categories_refresh_search
  after insert or delete on public.provider_categories
  for each row execute function public.provider_categories_refresh_search();

-- RLS
alter table public.providers enable row level security;

create policy providers_select on public.providers
  for select to anon, authenticated
  using (status = 'published' or owner_id = (select auth.uid()) or public.is_admin());

create policy providers_owner_insert on public.providers
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy providers_owner_update on public.providers
  for update to authenticated
  using (owner_id = (select auth.uid()) and status <> 'suspended')
  with check (owner_id = (select auth.uid()));

create policy providers_owner_delete on public.providers
  for delete to authenticated
  using (owner_id = (select auth.uid()) and status <> 'suspended');

create policy providers_admin_all on public.providers
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Hijas: lectura = visibilidad del prestador padre (reusa su RLS); escritura = dueno no suspendido o admin.
do $$
declare
  t text;
begin
  foreach t in array array['provider_categories', 'services', 'provider_coverage_areas',
                           'business_hours', 'availability_status', 'provider_images']
  loop
    execute format('alter table public.%I enable row level security', t);

    execute format($f$
      create policy %I on public.%I for select to anon, authenticated
      using (exists (select 1 from public.providers p where p.id = provider_id))
    $f$, t || '_select', t);

    execute format($f$
      create policy %I on public.%I for all to authenticated
      using (
        public.is_admin() or exists (
          select 1 from public.providers p
          where p.id = provider_id and p.owner_id = (select auth.uid()) and p.status <> 'suspended')
      )
      with check (
        public.is_admin() or exists (
          select 1 from public.providers p
          where p.id = provider_id and p.owner_id = (select auth.uid()) and p.status <> 'suspended')
      )
    $f$, t || '_owner_admin_write', t);

    execute format('revoke insert, update, delete, truncate on public.%I from anon', t);
  end loop;
end $$;

revoke insert, update, delete, truncate on public.providers from anon;
