begin;
select plan(23);

create function pg_temp.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- O: duena de un prestador publicado. X: duena de un borrador. ADM: admin.
insert into auth.users (id, aud, role, email) values
  ('b1000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'o@test.invalid'),
  ('b1000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'x@test.invalid'),
  ('b1000000-0000-0000-0000-00000000000c', 'authenticated', 'authenticated', 'adm@test.invalid');
update public.profiles set role = 'admin' where id = 'b1000000-0000-0000-0000-00000000000c';

insert into public.providers (id, owner_id, slug, business_name, provider_type, whatsapp, status, description) values
  ('c1000000-0000-0000-0000-00000000000a', 'b1000000-0000-0000-0000-00000000000a', 't-pub', 'Test Publicado', 'professional', '+5493884000001', 'published', 'Trabajos varios'),
  ('c1000000-0000-0000-0000-00000000000b', 'b1000000-0000-0000-0000-00000000000b', 't-draft', 'Test Borrador', 'business', null, 'draft', null);

insert into public.services (id, provider_id, name, price_from) values
  ('d1000000-0000-0000-0000-00000000000a', 'c1000000-0000-0000-0000-00000000000a', 'Servicio publico', 1000),
  ('d1000000-0000-0000-0000-00000000000b', 'c1000000-0000-0000-0000-00000000000b', 'Servicio borrador', 500);

-- anon
set local role anon;
select is((select count(*)::int from public.providers where slug in ('t-pub', 't-draft')), 1,
  'anon ve solo prestadores publicados');
select is((select count(*)::int from public.services where id in ('d1000000-0000-0000-0000-00000000000a', 'd1000000-0000-0000-0000-00000000000b')), 1,
  'anon ve solo servicios de prestadores publicados');
select throws_ok(
  $$insert into public.providers (owner_id, slug, business_name, provider_type)
    values ('b1000000-0000-0000-0000-00000000000b', 't-anon', 'Anon', 'business')$$,
  '42501', null, 'anon no puede insertar prestadores');
reset role;

-- X (duena del borrador)
select pg_temp.login('b1000000-0000-0000-0000-00000000000b');

select is((select count(*)::int from public.providers where slug = 't-draft'), 1, 'la duena ve su borrador');
select throws_ok($$update public.providers set status = 'published' where slug = 't-draft'$$,
  '42501', null, 'la duena no puede publicar su prestador');
select throws_ok($$update public.providers set verified_at = now() where slug = 't-draft'$$,
  '42501', null, 'la duena no puede marcarse como verificada');
select throws_ok($$update public.providers set is_demo = true where slug = 't-draft'$$,
  '42501', null, 'la duena no puede marcarse como demo');
select lives_ok($$update public.providers set status = 'pending_review' where slug = 't-draft'$$,
  'la duena puede enviar a revision (draft -> pending_review)');
select throws_ok(
  $$insert into public.providers (owner_id, slug, business_name, provider_type, status)
    values ('b1000000-0000-0000-0000-00000000000b', 't-x2', 'Directo publicado', 'business', 'published')$$,
  '42501', null, 'no se puede crear un prestador directamente publicado');
select throws_ok(
  $$insert into public.providers (owner_id, slug, business_name, provider_type)
    values ('b1000000-0000-0000-0000-00000000000a', 't-x3', 'Ajeno', 'business')$$,
  '42501', null, 'no se puede crear un prestador a nombre de otro usuario');
select lives_ok(
  $$insert into public.providers (owner_id, slug, business_name, provider_type)
    values ('b1000000-0000-0000-0000-00000000000b', 't-x4', 'Segundo borrador', 'business')$$,
  'la duena puede crear un borrador propio');
select lives_ok($$update public.providers set business_name = 'Hack' where slug = 't-pub'$$,
  'editar prestador ajeno no falla pero no afecta filas');
select throws_ok(
  $$insert into public.services (provider_id, name) values ('c1000000-0000-0000-0000-00000000000a', 'Colado')$$,
  '42501', null, 'no se pueden crear servicios en un prestador ajeno');
select lives_ok($$delete from public.services where provider_id = 'c1000000-0000-0000-0000-00000000000a'$$,
  'borrar servicios ajenos no falla pero no afecta filas');
select lives_ok(
  $$insert into public.services (provider_id, name, price_from) values ('c1000000-0000-0000-0000-00000000000b', 'Propio', 100)$$,
  'la duena puede crear servicios en su prestador');
reset role;

select is((select business_name from public.providers where slug = 't-pub'), 'Test Publicado',
  'el prestador ajeno no fue modificado');
select is((select count(*)::int from public.services where provider_id = 'c1000000-0000-0000-0000-00000000000a'), 1,
  'los servicios ajenos no fueron borrados');

-- suspension: desaparece para anon y la duena no puede editar
update public.providers set status = 'suspended' where slug = 't-pub';
set local role anon;
select is((select count(*)::int from public.providers where slug = 't-pub'), 0, 'un prestador suspendido no es visible para anon');
reset role;
select pg_temp.login('b1000000-0000-0000-0000-00000000000a');
update public.providers set business_name = 'Editado suspendido' where slug = 't-pub';
reset role;
select is((select business_name from public.providers where slug = 't-pub'), 'Test Publicado',
  'un prestador suspendido no puede ser editado por su duena');

-- admin
select pg_temp.login('b1000000-0000-0000-0000-00000000000c');
select throws_ok(
  $$update public.providers set status = 'published' where slug = 't-draft'$$,
  '23514', null, 'ni un admin puede publicar un prestador sin WhatsApp');
select lives_ok(
  $$update public.providers set whatsapp = '+5493884000002', status = 'published', verified_at = now(), published_at = now() where slug = 't-draft'$$,
  'un admin puede publicar y verificar un prestador con WhatsApp');
reset role;
select is((select status::text from public.providers where slug = 't-draft'), 'published', 'el cambio del admin quedo aplicado');

-- search_vector
insert into public.provider_categories (provider_id, category_id)
  select 'c1000000-0000-0000-0000-00000000000b', id from public.categories where slug = 'plomeria';
select ok((select search_vector::text from public.providers where slug = 't-draft') like '%plomeri%',
  'search_vector incorpora las categorias asignadas');

select * from finish();
rollback;
