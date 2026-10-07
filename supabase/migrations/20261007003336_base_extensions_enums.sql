-- 0001: extensiones, enums y helper de timestamps.

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

create type public.user_role as enum ('client', 'provider', 'admin');
create type public.provider_type as enum ('professional', 'business');
create type public.provider_status as enum ('draft', 'pending_review', 'published', 'suspended');
create type public.availability_state as enum ('available_now', 'available_today', 'unavailable');
create type public.location_kind as enum ('province', 'city', 'zone');

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
