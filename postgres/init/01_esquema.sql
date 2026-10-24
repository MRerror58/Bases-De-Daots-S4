-- 01_esquema.sql
-- Proyecto Biblioteca - Grupo 1
-- Base corregida a partir del modelo de S8 y preparada para S14.
-- PostgreSQL

DROP SCHEMA IF EXISTS biblioteca CASCADE;
CREATE SCHEMA biblioteca;
SET search_path TO biblioteca;

-- ============================================================
-- TABLAS DEL MODELO
-- ============================================================

CREATE TABLE usuario (
    id_usuario       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_usuario   varchar(120) NOT NULL UNIQUE,
    contrasena_hash  varchar(255) NOT NULL,
    rol              varchar(20) NOT NULL
                     CHECK (rol IN ('lector', 'bibliotecario', 'administrador', 'auditor')),
    activo            boolean NOT NULL DEFAULT true,
    fecha_creacion    timestamp NOT NULL DEFAULT now()
);

CREATE TABLE lector (
    id_lector       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario      integer NOT NULL UNIQUE,

    documento       varchar(15) NOT NULL UNIQUE
                    CHECK (documento ~ '^[0-9]{6,15}$'),

    nombres         varchar(80) NOT NULL
                    CHECK (btrim(nombres) <> ''),

    apellidos       varchar(80) NOT NULL
                    CHECK (btrim(apellidos) <> ''),

    correo          varchar(120) NOT NULL UNIQUE
                    CHECK (correo ~ '^[^@ ]+@[^@ ]+\.[^@ ]+$'),

    telefono        varchar(15)
                    CHECK (
                        telefono IS NULL
                        OR telefono ~ '^[0-9]{7,15}$'
                    ),

    direccion       varchar(200),
    fecha_registro  date NOT NULL DEFAULT CURRENT_DATE,
    activo          boolean NOT NULL DEFAULT true,

    CONSTRAINT fk_lector_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
);

CREATE TABLE libro (
    isbn                    varchar(13) PRIMARY KEY
                            CHECK (isbn ~ '^[0-9]{13}$'),

    titulo                  varchar(200) NOT NULL
                            CHECK (btrim(titulo) <> ''),

    autor                   varchar(120) NOT NULL
                            CHECK (btrim(autor) <> ''),

    categoria               varchar(40) NOT NULL
                            CHECK (btrim(categoria) <> ''),

    editorial               varchar(120),

    anio_publicacion        smallint NOT NULL
                            CHECK (anio_publicacion BETWEEN 1450 AND 2100),

    ejemplares_disponibles  integer NOT NULL
                            CHECK (ejemplares_disponibles >= 0),

    activo                  boolean NOT NULL DEFAULT true
);

CREATE TABLE prestamo (
    id_prestamo       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    id_lector         integer NOT NULL,
    isbn              varchar(13) NOT NULL,

    -- Usuario con rol bibliotecario que registra el préstamo
    registrado_por    integer NOT NULL,

    -- Puede ser NULL mientras el libro no haya sido devuelto
    devuelto_por      integer,

    fecha_prestamo    date NOT NULL,
    fecha_vencimiento date NOT NULL,
    fecha_devolucion  date,

    CONSTRAINT fk_prestamo_lector
        FOREIGN KEY (id_lector)
        REFERENCES lector(id_lector),

    CONSTRAINT fk_prestamo_libro
        FOREIGN KEY (isbn)
        REFERENCES libro(isbn),

    CONSTRAINT fk_prestamo_registrado_por
        FOREIGN KEY (registrado_por)
        REFERENCES usuario(id_usuario),

    CONSTRAINT fk_prestamo_devuelto_por
        FOREIGN KEY (devuelto_por)
        REFERENCES usuario(id_usuario),

    CONSTRAINT chk_fecha_vencimiento
        CHECK (fecha_vencimiento >= fecha_prestamo),

    CONSTRAINT chk_fecha_devolucion
        CHECK (
            fecha_devolucion IS NULL
            OR fecha_devolucion >= fecha_prestamo
        )
);

-- ============================================================
-- INFRAESTRUCTURA PARA S14: CARGA DESDE CSV
-- No forman parte del modelo conceptual; sirven para staging,
-- validación y registro de filas rechazadas.
-- ============================================================

CREATE TABLE rechazo_carga (
    id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    archivo    text NOT NULL,
    linea      integer NOT NULL,
    contenido  text NOT NULL,
    motivo     text NOT NULL,
    fecha      timestamptz NOT NULL DEFAULT now()
);

-- Guarda cada línea del archivo completa antes de partirla.
CREATE TABLE stg_linea (
    n      integer GENERATED ALWAYS AS IDENTITY,
    linea  text
);

-- Staging de libros: todo se recibe como texto.
CREATE TABLE stg_libro (
    linea_csv               integer,
    contenido               text,
    num_campos              integer,
    isbn                    text,
    titulo                  text,
    autor                   text,
    categoria               text,
    anio_publicacion        text,
    ejemplares_disponibles  text,
    motivo                  text
);

-- Staging de lectores: todo se recibe como texto.
CREATE TABLE stg_lector (
    linea_csv   integer,
    contenido   text,
    num_campos  integer,
    documento   text,
    nombres     text,
    apellidos   text,
    correo      text,
    telefono    text,
    motivo      text
);

-- ============================================================
-- FIN DEL ESQUEMA
-- ============================================================
