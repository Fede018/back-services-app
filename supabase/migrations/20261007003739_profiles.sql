-- 0002: profiles, is_admin(), alta automatica y bloqueo de escalada de rol.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  avatar_url text,
  role public.user_role not null default 'client',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- is_admin(): lee el rol real desde la tabla, nunca desde el JWT ni metadata del usuario.
create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated, service_role;

-- Alta automatica: siempre 'client'. Solo se toma full_name de la metadata.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, nullif(left(new.raw_user_meta_data ->> 'full_name', 120), ''), 'client');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Bloqueo de escalada: el rol y el id solo cambian por un admin o roles internos.
-- Las funciones security definer (duenas: postgres) pasan por current_user.
create function public.profiles_guard_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'profiles.id es inmutable' using errcode = '42501';
  end if;
  if new.role is distinct from old.role
     and current_user not in ('postgres', 'service_role', 'supabase_admin')
     and not public.is_admin() then
    raise exception 'no autorizado a cambiar el rol' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_guard_columns
  before update on public.profiles
  for each row execute function public.profiles_guard_columns();

alter table public.profiles enable row level security;

create policy profiles_select_own_or_admin on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy profiles_update_admin on public.profiles
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Sin policies de insert/delete: el alta la hace el trigger y el borrado cascada desde auth.users.
revoke all on public.profiles from anon;
