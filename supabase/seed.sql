-- Datos DEMO solo para desarrollo local. Nunca se aplican al proyecto cloud (db push no ejecuta seed).
-- Todos los prestadores: is_demo = true y nombre con prefijo [DEMO]. Telefonos ficticios (+549388000000X).
-- Los usuarios demo no tienen contrasena: no se puede iniciar sesion con ellos.

insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select ('d0000000-0000-0000-0000-00000000000' || n)::uuid,
       'authenticated', 'authenticated',
       'demo' || n || '@yunta.invalid',
       jsonb_build_object('full_name', 'Demo ' || n),
       now(), now()
from generate_series(1, 8) as n
on conflict (id) do nothing;

insert into public.providers
  (id, owner_id, slug, business_name, provider_type, description, whatsapp, phone, location_id,
   offers_home_visit, offers_delivery, status, verified_at, is_demo, published_at)
select v.id::uuid, v.owner::uuid, v.slug, v.name, v.ptype::public.provider_type, v.descr, v.wsp, null,
       (select id from public.locations where slug = v.loc),
       v.home, v.delivery, v.status::public.provider_status,
       case when v.verified then now() end, true,
       case when v.status = 'published' then now() end
from (values
  ('e0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','demo-electricidad-jujuy','[DEMO] Electricidad Jujuy','professional',
   'Instalaciones y reparaciones electricas domiciliarias. Presupuesto sin cargo.','+5493880000001','san-salvador-de-jujuy',true,false,'published',true),
  ('e0000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000002','demo-plomeria-norte','[DEMO] Plomeria del Norte','professional',
   'Destapaciones, perdidas de agua y colocacion de sanitarios. Urgencias.','+5493880000002','san-salvador-de-jujuy',true,false,'published',false),
  ('e0000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000003','demo-sabores-de-casa','[DEMO] Sabores de Casa','business',
   'Viandas y comida casera por encargo, con entrega a domicilio.','+5493880000003','san-salvador-de-jujuy',false,true,'published',true),
  ('e0000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000004','demo-frio-service','[DEMO] Frio Service','business',
   'Instalacion y service de aires acondicionados y heladeras.','+5493880000004','palpala',true,false,'published',false),
  ('e0000000-0000-0000-0000-000000000005','d0000000-0000-0000-0000-000000000005','demo-garrafas-jujuy','[DEMO] Garrafas Jujuy','business',
   'Venta y reparto de garrafas de 10 y 15 kg.','+5493880000005','san-salvador-de-jujuy',false,true,'published',true),
  ('e0000000-0000-0000-0000-000000000006','d0000000-0000-0000-0000-000000000006','demo-lavarropas-fix','[DEMO] Lavarropas Fix','professional',
   'Reparacion de lavarropas y otros electrodomesticos, con retiro y entrega.','+5493880000006','palpala',true,false,'published',false),
  ('e0000000-0000-0000-0000-000000000007','d0000000-0000-0000-0000-000000000007','demo-pintura-en-revision','[DEMO] Pintura en revision','professional',
   'Perfil de prueba pendiente de aprobacion: no debe verse publicamente.','+5493880000007','san-salvador-de-jujuy',true,false,'pending_review',false),
  ('e0000000-0000-0000-0000-000000000008','d0000000-0000-0000-0000-000000000008','demo-borrador','[DEMO] Borrador sin publicar','professional',
   'Perfil de prueba en borrador: no debe verse publicamente.',null,'san-salvador-de-jujuy',false,false,'draft',false)
) as v(id, owner, slug, name, ptype, descr, wsp, loc, home, delivery, status, verified)
on conflict (id) do nothing;

insert into public.provider_categories (provider_id, category_id)
select p.id, c.id
from (values
  ('demo-electricidad-jujuy','electricidad'),
  ('demo-plomeria-norte','plomeria'),
  ('demo-sabores-de-casa','comida-casera'),
  ('demo-sabores-de-casa','gastronomia'),
  ('demo-frio-service','refrigeracion'),
  ('demo-garrafas-jujuy','venta-de-productos'),
  ('demo-garrafas-jujuy','delivery'),
  ('demo-lavarropas-fix','reparacion-electrodomesticos'),
  ('demo-pintura-en-revision','pintura'),
  ('demo-borrador','otros')
) as v(pslug, cslug)
join public.providers p on p.slug = v.pslug
join public.categories c on c.slug = v.cslug
on conflict do nothing;

insert into public.services (provider_id, name, description, price_from, price_to, price_unit)
select p.id, v.name, v.descr, v.pfrom, v.pto, v.unit
from (values
  ('demo-electricidad-jujuy','Instalacion electrica','Tableros, tomas y luminarias',12000,25000,'por trabajo'),
  ('demo-electricidad-jujuy','Visita de diagnostico','Revision de fallas',6000,null,'por visita'),
  ('demo-plomeria-norte','Destapacion de cañerias',null,15000,30000,'por trabajo'),
  ('demo-plomeria-norte','Reparacion de perdidas',null,10000,22000,'por trabajo'),
  ('demo-sabores-de-casa','Vianda del dia','Plato principal mas postre',3500,4500,'por porcion'),
  ('demo-sabores-de-casa','Empanadas salteñas',null,900,null,'por unidad'),
  ('demo-frio-service','Instalacion de aire split',null,60000,90000,'por trabajo'),
  ('demo-frio-service','Service de heladera',null,18000,null,'por trabajo'),
  ('demo-garrafas-jujuy','Garrafa 10 kg','Reparto en zona centro',12500,null,'por unidad'),
  ('demo-garrafas-jujuy','Garrafa 15 kg','Reparto en zona centro',18500,null,'por unidad'),
  ('demo-lavarropas-fix','Reparacion de lavarropas',null,15000,40000,'por trabajo'),
  ('demo-pintura-en-revision','Pintura de interiores',null,8000,null,'por m2'),
  ('demo-borrador','Servicio de prueba',null,null,null,null)
) as v(pslug, name, descr, pfrom, pto, unit)
join public.providers p on p.slug = v.pslug;

insert into public.provider_coverage_areas (provider_id, location_id)
select p.id, l.id
from public.providers p
join public.locations l on l.slug in ('san-salvador-de-jujuy', 'palpala')
where p.is_demo and p.slug <> 'demo-borrador';

insert into public.business_hours (provider_id, weekday, opens_at, closes_at)
select p.id, d, '08:00', '20:00'
from public.providers p, generate_series(1, 5) as d
where p.is_demo and p.slug <> 'demo-borrador';

insert into public.business_hours (provider_id, weekday, opens_at, closes_at)
select p.id, 6, '09:00', '13:00'
from public.providers p
where p.slug in ('demo-electricidad-jujuy', 'demo-sabores-de-casa', 'demo-garrafas-jujuy');

insert into public.availability_status (provider_id, state, note, updated_at)
select p.id, v.state::public.availability_state, v.note, now() - v.ago
from (values
  ('demo-electricidad-jujuy','available_now','Disponible ahora para urgencias', interval '20 minutes'),
  ('demo-plomeria-norte','available_today','Atiendo a partir de las 16 hs', interval '3 hours'),
  ('demo-sabores-de-casa','available_today','Pedidos hasta las 11 hs', interval '5 hours'),
  ('demo-frio-service','unavailable',null, interval '2 days'),
  ('demo-garrafas-jujuy','available_now',null, interval '10 minutes'),
  ('demo-lavarropas-fix','available_today',null, interval '1 day')
) as v(pslug, state, note, ago)
join public.providers p on p.slug = v.pslug;
