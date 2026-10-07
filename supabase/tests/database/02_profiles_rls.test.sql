begin;
select plan(12);

create function pg_temp.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- U1: intenta escalar a admin via metadata. U2: usuario comun. U3: sera admin.
insert into auth.users (id, aud, role, email, raw_user_meta_data) values
  ('a1000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 't1@test.invalid', '{"full_name":"Uno","role":"admin"}'),
  ('a1000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 't2@test.invalid', '{"full_name":"Dos"}'),
  ('a1000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 't3@test.invalid', '{}');

select is((select role::text from public.profiles where id = 'a1000000-0000-0000-0000-000000000001'),
  'client', 'registro con role=admin en metadata queda como client');

select is((select full_name from public.profiles where id = 'a1000000-0000-0000-0000-000000000001'),
  'Uno', 'full_name se toma de la metadata');

select pg_temp.login('a1000000-0000-0000-0000-000000000001');

select throws_ok(
  $$update public.profiles set role = 'admin' where id = 'a1000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'un usuario no puede asignarse el rol admin');

select lives_ok(
  $$update public.profiles set full_name = 'Uno B' where id = 'a1000000-0000-0000-0000-000000000001'$$,
  'un usuario puede editar su propio nombre');

select is((select count(*)::int from public.profiles where id <> 'a1000000-0000-0000-0000-000000000001'), 0,
  'un usuario no ve perfiles ajenos');

select lives_ok(
  $$update public.profiles set full_name = 'Hack' where id = 'a1000000-0000-0000-0000-000000000002'$$,
  'editar perfil ajeno no falla pero no afecta filas');

reset role;

select is((select full_name from public.profiles where id = 'a1000000-0000-0000-0000-000000000002'),
  'Dos', 'el perfil ajeno no fue modificado');

set local role anon;
select throws_ok($$select * from public.profiles$$, '42501', null, 'anon no puede leer profiles');
reset role;

update public.profiles set role = 'admin' where id = 'a1000000-0000-0000-0000-000000000003';
select pg_temp.login('a1000000-0000-0000-0000-000000000003');

select lives_ok(
  $$update public.profiles set role = 'provider' where id = 'a1000000-0000-0000-0000-000000000002'$$,
  'un admin puede cambiar el rol de otro usuario');

select is((select count(*)::int from public.profiles
            where id in ('a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002',
                         'a1000000-0000-0000-0000-000000000003')),
  3, 'un admin ve todos los perfiles');

reset role;

select is((select role::text from public.profiles where id = 'a1000000-0000-0000-0000-000000000002'),
  'provider', 'el cambio de rol del admin quedo aplicado');

select throws_ok(
  $$update public.profiles set id = 'a1000000-0000-0000-0000-0000000000ff' where id = 'a1000000-0000-0000-0000-000000000001'$$,
  '42501', null, 'profiles.id es inmutable');

select * from finish();
rollback;
