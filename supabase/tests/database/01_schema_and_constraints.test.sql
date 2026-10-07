begin;
select plan(15);

select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
      and c.relname in ('profiles', 'locations', 'categories', 'providers', 'provider_categories',
                        'services', 'provider_coverage_areas', 'business_hours',
                        'availability_status', 'provider_images')),
  10, 'las 10 tablas nucleo tienen RLS');

select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0, 'ninguna tabla de public queda sin RLS');

select is((select count(*)::int from public.categories where is_active), 23, '23 categorias activas');

select is((select count(*)::int from public.locations where kind = 'city' and is_active), 2,
  '2 ciudades activas');

select is(
  (select string_agg(slug, ',' order by slug) from public.locations where kind = 'city' and is_active),
  'palpala,san-salvador-de-jujuy', 'ciudades activas: San Salvador de Jujuy y Palpala');

select ok(exists (select 1 from pg_extension where extname = 'pg_trgm'), 'pg_trgm habilitada');
select ok(exists (select 1 from pg_extension where extname = 'unaccent'), 'unaccent habilitada');

select is((select file_size_limit from storage.buckets where id = 'provider-images'), 5242880::bigint,
  'bucket provider-images limitado a 5 MB');

select is((select allowed_mime_types from storage.buckets where id = 'provider-images'),
  array['image/jpeg', 'image/png', 'image/webp'], 'bucket provider-images solo acepta jpeg, png y webp');

select is(
  (select count(*)::int from public.providers where not is_demo or business_name not like '[DEMO]%'),
  0, 'todos los prestadores del seed son demo con prefijo [DEMO]');

select is((select count(*)::int from public.providers where search_vector is null), 0,
  'todos los prestadores tienen search_vector');

select throws_ok(
  $$insert into public.services (provider_id, name, currency)
    select id, 'Servicio USD', 'USD' from public.providers limit 1$$,
  '23514', null, 'services rechaza moneda distinta de ARS');

select throws_ok(
  $$update public.providers set whatsapp = '3884123456' where slug = 'demo-electricidad-jujuy'$$,
  '23514', null, 'providers rechaza WhatsApp sin formato E.164');

select throws_ok(
  $$insert into public.business_hours (provider_id, weekday, opens_at, closes_at)
    select id, 1, '20:00', '08:00' from public.providers limit 1$$,
  '23514', null, 'business_hours rechaza cierre anterior a apertura');

select throws_ok(
  $$insert into public.services (provider_id, name, price_from, price_to)
    select id, 'Rango invalido', 500, 100 from public.providers limit 1$$,
  '23514', null, 'services rechaza price_to menor que price_from');

select * from finish();
rollback;
