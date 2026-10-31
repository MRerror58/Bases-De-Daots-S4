-- S16. Taller de consultas complejas
-- Caso: una tienda en línea de café (clientes, productos, pedidos)
--
-- Uso (desde entorno-docker/, con este archivo copiado en postgres/scripts/):
--   docker compose exec postgres psql -U curso -d curso -f /scripts/S16-tienda.sql
--
-- Se puede correr cuantas veces se quiera: borra y recrea el esquema
-- "tienda" completo, sin tocar nada más de la base.
-- Para trabajar después sobre estas tablas desde psql o pgAdmin:
--   SET search_path TO tienda;

\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS tienda CASCADE;
CREATE SCHEMA tienda;
SET search_path TO tienda;

CREATE TABLE cliente (
    id_cliente    integer      PRIMARY KEY,
    nombre        varchar(80)  NOT NULL,
    ciudad        varchar(40)  NOT NULL,
    referido_por  integer      REFERENCES cliente (id_cliente)
);

CREATE TABLE producto (
    id_producto  integer        PRIMARY KEY,
    nombre       varchar(80)    NOT NULL UNIQUE,
    categoria    varchar(20)    NOT NULL CHECK (categoria IN ('Grano', 'Molido', 'Accesorio')),
    precio       numeric(10,0)  NOT NULL CHECK (precio > 0)
);

CREATE TABLE pedido (
    id_pedido   integer      PRIMARY KEY,
    id_cliente  integer      NOT NULL REFERENCES cliente (id_cliente),
    fecha       date         NOT NULL,
    estado      varchar(10)  NOT NULL CHECK (estado IN ('pagado', 'enviado', 'cancelado'))
);

CREATE TABLE detalle (
    id_pedido        integer        REFERENCES pedido (id_pedido),
    id_producto      integer        REFERENCES producto (id_producto),
    cantidad         integer        NOT NULL CHECK (cantidad > 0),
    precio_unitario  numeric(10,0)  NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (id_pedido, id_producto)
);

INSERT INTO cliente (id_cliente, nombre, ciudad, referido_por) VALUES
    (1, 'Laura Ortiz',      'Cali',     NULL),
    (4, 'Felipe Cárdenas',  'Bogotá',   NULL),
    (6, 'Jorge Salazar',    'Pasto',    NULL),
    (8, 'Óscar Vélez',      'Palmira',  NULL),
    (2, 'Andrés Mejía',     'Cali',     1),
    (3, 'Paula Restrepo',   'Medellín', 1),
    (5, 'Daniela Rincón',   'Cali',     4),
    (7, 'Natalia Quintero', 'Medellín', 3);

INSERT INTO producto (id_producto, nombre, categoria, precio) VALUES
    (101, 'Café de origen Huila 500 g',    'Grano',      38000),
    (102, 'Café de origen Nariño 500 g',   'Grano',      42000),
    (103, 'Café de origen Cauca 500 g',    'Grano',      40000),
    (104, 'Café molido tradicional 500 g', 'Molido',     22000),
    (105, 'Café molido descafeinado 250 g','Molido',     18000),
    (110, 'Café molido premium 500 g',     'Molido',     30000),
    (106, 'Prensa francesa',               'Accesorio',  95000),
    (107, 'Filtro de tela',                'Accesorio',  12000),
    (108, 'Molino manual',                 'Accesorio', 150000),
    (109, 'Taza de cerámica',              'Accesorio',  25000);

INSERT INTO pedido (id_pedido, id_cliente, fecha, estado) VALUES
    (1001, 1, '2026-01-15', 'enviado'),
    (1002, 2, '2026-01-20', 'enviado'),
    (1003, 1, '2026-02-03', 'enviado'),
    (1004, 3, '2026-02-10', 'cancelado'),
    (1005, 4, '2026-02-18', 'enviado'),
    (1006, 5, '2026-03-05', 'pagado'),
    (1007, 3, '2026-03-12', 'enviado'),
    (1008, 2, '2026-03-25', 'enviado'),
    (1009, 1, '2026-04-02', 'pagado'),
    (1010, 7, '2026-04-08', 'enviado'),
    (1011, 4, '2026-04-15', 'cancelado'),
    (1012, 8, '2026-04-20', 'pagado'),
    (1013, 2, '2026-05-02', 'cancelado'),
    (1014, 4, '2026-05-10', 'enviado');

INSERT INTO detalle (id_pedido, id_producto, cantidad, precio_unitario) VALUES
    (1001, 101, 2,  38000),
    (1001, 102, 1,  42000),
    (1001, 107, 1,  12000),
    (1002, 104, 3,  22000),
    (1003, 103, 1,  40000),
    (1003, 106, 1,  95000),
    (1004, 108, 1, 150000),
    (1005, 101, 1,  38000),
    (1005, 102, 1,  42000),
    (1005, 103, 1,  40000),
    (1006, 105, 2,  18000),
    (1006, 107, 2,  12000),
    (1007, 110, 2,  30000),
    (1008, 101, 1,  38000),
    (1009, 104, 1,  22000),
    (1010, 108, 1, 150000),
    (1010, 106, 1,  95000),
    (1010, 102, 1,  42000),
    (1011, 106, 1,  95000),
    (1012, 102, 2,  42000),
    (1013, 102, 1,  42000),
    (1013, 103, 1,  40000),
    (1014, 101, 1,  38000);
