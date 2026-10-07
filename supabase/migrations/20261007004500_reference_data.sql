-- 0004: datos de referencia reales (se aplican tambien en cloud). Idempotente.

insert into public.locations (name, slug, kind, lat, lng, is_active, sort_order) values
  ('Jujuy', 'jujuy', 'province', null, null, true, 0)
on conflict (slug) do nothing;

insert into public.locations (parent_id, name, slug, kind, lat, lng, is_active, sort_order)
select p.id, v.name, v.slug, 'city', v.lat, v.lng, v.is_active, v.sort_order
from public.locations p,
  (values
    ('San Salvador de Jujuy',        'san-salvador-de-jujuy',        -24.185800::numeric, -65.299500::numeric, true,  1),
    ('Palpalá',                      'palpala',                      -24.257500::numeric, -65.210300::numeric, true,  2),
    ('Perico',                       'perico',                       -24.379200::numeric, -65.113600::numeric, false, 3),
    ('El Carmen',                    'el-carmen',                    -24.387500::numeric, -65.267200::numeric, false, 4),
    ('San Pedro de Jujuy',           'san-pedro-de-jujuy',           -24.231400::numeric, -64.867200::numeric, false, 5),
    ('Libertador General San Martín','libertador-general-san-martin',-23.812800::numeric, -64.788600::numeric, false, 6)
  ) as v(name, slug, lat, lng, is_active, sort_order)
where p.slug = 'jujuy'
on conflict (slug) do nothing;

insert into public.categories (name, slug, icon, sort_order) values
  ('Electricidad',                   'electricidad',                  'zap',              1),
  ('Plomería',                       'plomeria',                      'droplets',         2),
  ('Gasistas',                       'gasistas',                      'flame',            3),
  ('Albañilería',                    'albanileria',                   'brick-wall',       4),
  ('Pintura',                        'pintura',                       'paint-roller',     5),
  ('Carpintería',                    'carpinteria',                   'hammer',           6),
  ('Refrigeración',                  'refrigeracion',                 'snowflake',        7),
  ('Reparación de electrodomésticos','reparacion-electrodomesticos',  'washing-machine',  8),
  ('Mecánica',                       'mecanica',                      'car-front',        9),
  ('Limpieza',                       'limpieza',                      'sparkles',        10),
  ('Jardinería',                     'jardineria',                    'sprout',          11),
  ('Mudanzas',                       'mudanzas',                      'truck',           12),
  ('Construcción',                   'construccion',                  'hard-hat',        13),
  ('Gastronomía',                    'gastronomia',                   'chef-hat',        14),
  ('Comida casera',                  'comida-casera',                 'soup',            15),
  ('Delivery',                       'delivery',                      'bike',            16),
  ('Comercios',                      'comercios',                     'store',           17),
  ('Venta de productos',             'venta-de-productos',            'shopping-bag',    18),
  ('Belleza',                        'belleza',                       'scissors',        19),
  ('Clases particulares',            'clases-particulares',           'graduation-cap',  20),
  ('Informática',                    'informatica',                   'laptop',          21),
  ('Servicios para mascotas',        'servicios-mascotas',            'paw-print',       22),
  ('Otros',                          'otros',                         'ellipsis',        99)
on conflict (slug) do nothing;
