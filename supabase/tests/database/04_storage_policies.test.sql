begin;
select plan(7);

create function pg_temp.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

insert into auth.users (id, aud, role, email) values
  ('e1000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'so@test.invalid'),
  ('e1000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'sx@test.invalid'),
  ('e1000000-0000-0000-0000-00000000000c', 'authenticated', 'authenticated', 'sadm@test.invalid');
update public.profiles set role = 'admin' where id = 'e1000000-0000-0000-0000-00000000000c';

insert into public.providers (id, owner_id, slug, business_name, provider_type)
values ('f1000000-0000-0000-0000-00000000000a', 'e1000000-0000-0000-0000-00000000000a', 's-prov', 'Storage Test', 'business');

select pg_temp.login('e1000000-0000-0000-0000-00000000000a');
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner)
    values ('provider-images', 'f1000000-0000-0000-0000-00000000000a/foto.jpg', 'e1000000-0000-0000-0000-00000000000a')$$,
  'la duena sube a la carpeta de su prestador');
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner)
    values ('provider-images', '00000000-0000-0000-0000-000000000000/foto.jpg', 'e1000000-0000-0000-0000-00000000000a')$$,
  '42501', null, 'la duena no puede subir a una carpeta que no es de su prestador');
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner)
    values ('provider-images', 'no-es-uuid/foto.jpg', 'e1000000-0000-0000-0000-00000000000a')$$,
  '42501', null, 'una carpeta que no es un id de prestador es rechazada');
reset role;

select pg_temp.login('e1000000-0000-0000-0000-00000000000b');
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner)
    values ('provider-images', 'f1000000-0000-0000-0000-00000000000a/colado.jpg', 'e1000000-0000-0000-0000-00000000000b')$$,
  '42501', null, 'otro usuario no puede subir a la carpeta ajena');
reset role;

set local role anon;
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('provider-images', 'f1000000-0000-0000-0000-00000000000a/anon.jpg')$$,
  '42501', null, 'anon no puede subir');
select is((select count(*)::int from storage.objects where bucket_id = 'provider-images'
            and name = 'f1000000-0000-0000-0000-00000000000a/foto.jpg'), 1,
  'anon puede leer objetos del bucket publico');
reset role;

select pg_temp.login('e1000000-0000-0000-0000-00000000000c');
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner)
    values ('provider-images', 'f1000000-0000-0000-0000-00000000000a/admin.jpg', 'e1000000-0000-0000-0000-00000000000c')$$,
  'un admin puede subir a cualquier carpeta');
reset role;

select * from finish();
rollback;
