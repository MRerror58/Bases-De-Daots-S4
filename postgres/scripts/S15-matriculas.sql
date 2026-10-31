-- S15. Consultas avanzadas: joins externos, agregación, subconsultas y división
-- Caso: las matrículas de S9 y S13, con dos filas más que no tienen pareja
--
-- Uso (desde entorno-docker/, con este archivo copiado en postgres/scripts/):
--   docker compose exec postgres psql -U curso -d curso -f /scripts/S15-matriculas.sql
--
-- Se puede correr cuantas veces se quiera: borra y recrea el esquema
-- "matriculas" completo (el mismo de S13), sin tocar nada más de la base.
-- Para trabajar después sobre estas tablas desde psql o pgAdmin:
--   SET search_path TO matriculas;

DROP SCHEMA IF EXISTS matriculas CASCADE;
CREATE SCHEMA matriculas;
SET search_path TO matriculas;

-- ---------------------------------------------------------------
-- DDL: las cuatro tablas de S9 y S13, sin cambios
-- ---------------------------------------------------------------

CREATE TABLE programa (
    cod_prog     integer      PRIMARY KEY,
    nombre_prog  varchar(80)  NOT NULL UNIQUE
);

CREATE TABLE estudiante (
    cod_est   integer      PRIMARY KEY,
    nombre    varchar(80)  NOT NULL,
    cod_prog  integer      NOT NULL REFERENCES programa (cod_prog)
);

CREATE TABLE curso (
    cod_curso     varchar(10)  PRIMARY KEY,
    nombre_curso  varchar(80)  NOT NULL,
    creditos      smallint     NOT NULL CHECK (creditos BETWEEN 1 AND 10)
);

CREATE TABLE aprobo (
    cod_est    integer       REFERENCES estudiante (cod_est),
    cod_curso  varchar(10)   REFERENCES curso (cod_curso),
    nota       numeric(2,1)  NOT NULL CHECK (nota BETWEEN 3.0 AND 5.0),
    PRIMARY KEY (cod_est, cod_curso)
);

-- ---------------------------------------------------------------
-- DML: los datos de S9 y S13 ...
-- ---------------------------------------------------------------

INSERT INTO programa (cod_prog, nombre_prog) VALUES
    (3743, 'Ingeniería de Sistemas'),
    (3752, 'Estadística');

INSERT INTO estudiante (cod_est, nombre, cod_prog) VALUES
    (2610001, 'Ana',   3743),
    (2610002, 'Bruno', 3743),
    (2610003, 'Carla', 3752),
    (2610004, 'Diego', 3743);

INSERT INTO curso (cod_curso, nombre_curso, creditos) VALUES
    ('750006C', 'Bases de Datos', 4),
    ('750001C', 'Programación I', 3),
    ('760001C', 'Estadística I',  3);

INSERT INTO aprobo (cod_est, cod_curso, nota) VALUES
    (2610001, '750006C', 4.5),
    (2610001, '750001C', 3.8),
    (2610001, '760001C', 3.2),
    (2610002, '750001C', 4.0),
    (2610003, '760001C', 4.7),
    (2610004, '750006C', 3.0),
    (2610004, '750001C', 3.5);

-- ---------------------------------------------------------------
-- ... más dos filas sin pareja, para los joins externos y los conteos
-- en cero: una estudiante que aún no ha aprobado nada y un curso que
-- nadie ha aprobado. Son las mismas de los ejemplos de INSERT de S13.
-- ---------------------------------------------------------------

INSERT INTO estudiante (cod_est, nombre, cod_prog) VALUES
    (2610005, 'Elena', 3752);

INSERT INTO curso (cod_curso, nombre_curso, creditos) VALUES
    ('750090C', 'Seminario', 1);
