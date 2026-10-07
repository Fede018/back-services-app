-- 0006: bucket publico provider-images con limites y politicas por propietario.
-- Convencion de ruta: {provider_id}/{archivo}. La primera carpeta es el id del prestador.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'provider-images',
  'provider-images',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Lectura publica de los objetos del bucket.
create policy provider_images_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'provider-images');

-- Escritura: dueno del prestador (no suspendido) o admin, solo dentro de su carpeta.
create policy provider_images_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'provider-images'
    and (
      public.is_admin()
      or exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = (select auth.uid())
          and p.status <> 'suspended'
      )
    )
  );

create policy provider_images_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'provider-images'
    and (
      public.is_admin()
      or exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = (select auth.uid())
          and p.status <> 'suspended'
      )
    )
  )
  with check (
    bucket_id = 'provider-images'
    and (
      public.is_admin()
      or exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = (select auth.uid())
          and p.status <> 'suspended'
      )
    )
  );

create policy provider_images_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'provider-images'
    and (
      public.is_admin()
      or exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = (select auth.uid())
          and p.status <> 'suspended'
      )
    )
  );
