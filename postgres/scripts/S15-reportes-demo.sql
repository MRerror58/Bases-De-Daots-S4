-- S15. Los cuatro reportes del proyecto sobre un esquema mínimo
-- (referencia del profesor; cada grupo escribe los suyos sobre SU esquema)
--
-- Uso (desde entorno-docker/, con este archivo copiado en postgres/scripts/):
--   docker compose exec postgres psql -U curso -d curso -f /scripts/S15-reportes-demo.sql
--
-- Se puede correr cuantas veces se quiera: borra y recrea el esquema
-- "reportes_demo" completo y al final imprime los cuatro reportes.
--
-- Las fechas de los préstamos se calculan a partir de CURRENT_DATE, para
-- que los reportes de mora den lo mismo sin importar el día en que se
-- corra el script.

\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS reportes_demo CASCADE;
CREATE SCHEMA reportes_demo;
SET search_path TO reportes_demo;

-- ---------------------------------------------------------------
-- DDL: libro y lector como en carga_demo (S14), sin los ejemplares,
-- y una tabla de préstamos. La devolución NULL = préstamo abierto.
-- ---------------------------------------------------------------

CREATE TABLE libro (
    isbn       varchar(13)   PRIMARY KEY CHECK (isbn ~ '^[0-9]{13}$'),
    titulo     varchar(200)  NOT NULL,
    autor      varchar(120)  NOT NULL,
    categoria  varchar(40)   NOT NULL
);

CREATE TABLE lector (
    documento  varchar(15)   PRIMARY KEY,
    nombres    varchar(80)   NOT NULL,
    apellidos  varchar(80)   NOT NULL,
    correo     varchar(120)  NOT NULL UNIQUE,
    telefono   varchar(15)   NOT NULL
);

CREATE TABLE prestamo (
    id                integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    isbn              varchar(13)  NOT NULL REFERENCES libro (isbn),
    documento         varchar(15)  NOT NULL REFERENCES lector (documento),
    fecha_prestamo    date         NOT NULL,
    fecha_esperada    date         NOT NULL,
    fecha_devolucion  date,
    CHECK (fecha_esperada   >= fecha_prestamo),
    CHECK (fecha_devolucion >= fecha_prestamo)
);

-- ---------------------------------------------------------------
-- DML: 9 libros y 6 lectores de los CSV semilla
-- ---------------------------------------------------------------

INSERT INTO libro (isbn, titulo, autor, categoria) VALUES
    ('9780000000001', 'Cien años de soledad',            'Gabriel García Márquez', 'Novela'),
    ('9780000000003', 'Crónica de una muerte anunciada', 'Gabriel García Márquez', 'Novela'),
    ('9780000000004', 'Rayuela',                         'Julio Cortázar',         'Novela'),
    ('9780000000005', 'Pedro Páramo',                    'Juan Rulfo',             'Novela'),
    ('9780000000007', 'Ficciones',                       'Jorge Luis Borges',      'Cuento'),
    ('9780000000008', 'El Aleph',                        'Jorge Luis Borges',      'Cuento'),
    ('9780000000009', 'Don Quijote de la Mancha',        'Miguel de Cervantes',    'Novela'),
    ('9780000000010', 'La sombra del viento',            'Carlos Ruiz Zafón',      'Novela'),
    ('9780000000011', 'Como agua para chocolate',        'Laura Esquivel',         'Novela');

INSERT INTO lector (documento, nombres, apellidos, correo, telefono) VALUES
    ('1000000001', 'Mariana',    'Gómez Rojas',      'mariana.gomez@correo-ejemplo.edu.co',      '3001000001'),
    ('1000000002', 'Santiago',   'Rodríguez Pérez',  'santiago.rodriguez@correo-ejemplo.edu.co', '3001000002'),
    ('1000000003', 'Valentina',  'López Díaz',       'valentina.lopez@correo-ejemplo.edu.co',    '3001000003'),
    ('1000000004', 'Juan David', 'Martínez Ruiz',    'juan.martinez@correo-ejemplo.edu.co',      '3001000004'),
    ('1000000005', 'Camila',     'Hernández Torres', 'camila.hernandez@correo-ejemplo.edu.co',   '3001000005'),
    ('1000000006', 'Sebastián',  'González Morales', 'sebastian.gonzalez@correo-ejemplo.edu.co', '3001000006');

-- ---------------------------------------------------------------
-- DML: 15 préstamos, cada uno pensado para probar un caso de los reportes.
-- p = días atrás del préstamo; d = días atrás de la devolución (NULL si
-- sigue abierto). Plazo de 14 días: fecha_esperada = fecha_prestamo + 14.
-- ---------------------------------------------------------------

INSERT INTO prestamo (isbn, documento, fecha_prestamo, fecha_esperada, fecha_devolucion)
SELECT isbn, documento,
       CURRENT_DATE - p,
       CURRENT_DATE - p + 14,
       CURRENT_DATE - d
FROM (VALUES
    -- Mariana: 3 devueltos a tiempo
    ('9780000000001', '1000000001', 120, 110),
    ('9780000000004', '1000000001', 100,  90),
    ('9780000000007', '1000000001',  80,  70),
    -- Santiago: 3 devueltos; el Quijote, 6 días tarde (fue mora, ya no lo es)
    ('9780000000001', '1000000002',  95,  85),
    ('9780000000005', '1000000002',  75,  65),
    ('9780000000009', '1000000002',  60,  40),
    -- Valentina: 1 devuelto, 1 abierto en mora y 1 abierto todavía a tiempo
    ('9780000000001', '1000000003',  70,  60),
    ('9780000000010', '1000000003',  30, NULL),
    ('9780000000003', '1000000003',   5, NULL),
    -- Juan David: 0 devueltos y 3 abiertos (2 en mora; Rayuela vence hoy)
    ('9780000000001', '1000000004',  20, NULL),
    ('9780000000004', '1000000004',  14, NULL),
    ('9780000000007', '1000000004',  40, NULL),
    -- Camila: 2 devueltos y 1 abierto en mora
    ('9780000000004', '1000000005',  50,  45),
    ('9780000000011', '1000000005',  35,  30),
    ('9780000000005', '1000000005',  16, NULL)
    -- Sebastián: ningún préstamo
) AS v (isbn, documento, p, d);

-- ---------------------------------------------------------------
-- Los cuatro reportes (sección 8 de la guía de S15)
-- ---------------------------------------------------------------

\echo
\echo '== Reporte 1. Los libros más prestados (aquí, los 3 primeros con empates) =='
SELECT l.titulo, count(p.id) AS prestamos
FROM   libro l
LEFT JOIN prestamo p ON p.isbn = l.isbn
GROUP BY l.isbn, l.titulo
ORDER BY prestamos DESC
FETCH FIRST 3 ROWS WITH TIES;

\echo '== Reporte 2. El o los lectores que más libros han leído (préstamos devueltos) =='
WITH leidos AS (
    SELECT documento, count(*) AS devueltos
    FROM   prestamo
    WHERE  fecha_devolucion IS NOT NULL
    GROUP BY documento
)
SELECT r.nombres, r.apellidos, x.devueltos
FROM   leidos x
JOIN   lector r ON r.documento = x.documento
WHERE  x.devueltos = (SELECT max(devueltos) FROM leidos)
ORDER BY r.apellidos;

\echo '== Reporte 3. Lectores morosos =='
SELECT r.documento, r.nombres, r.apellidos
FROM   lector r
WHERE  EXISTS (SELECT 1
               FROM   prestamo p
               WHERE  p.documento = r.documento
                 AND  p.fecha_devolucion IS NULL
                 AND  p.fecha_esperada < CURRENT_DATE)
ORDER BY r.apellidos;

\echo '== Reporte 4. Préstamos en mora (para la lista de notificación) =='
SELECT r.nombres || ' ' || r.apellidos     AS lector,
       r.correo, r.telefono,
       l.titulo,
       p.fecha_esperada,
       CURRENT_DATE - p.fecha_esperada     AS dias_mora
FROM   prestamo p
JOIN   lector r ON r.documento = p.documento
JOIN   libro  l ON l.isbn      = p.isbn
WHERE  p.fecha_devolucion IS NULL
  AND  p.fecha_esperada < CURRENT_DATE
ORDER BY dias_mora DESC;
