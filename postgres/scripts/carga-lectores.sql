-- Carga de lectores desde CSV al esquema biblioteca (S14, Grupo 1)
-- Cada lector válido genera dos filas: su cuenta en usuario (rol 'lector') y
-- sus datos en lector. La contraseña inicial es el documento, guardada con
-- hash bcrypt (pgcrypto), nunca en texto plano; el lector debe cambiarla.
--
-- Uso (desde entorno-docker/, con los CSV en postgres/scripts/datos/):
--   docker compose exec postgres psql -U curso -d curso \
--     -v archivo=/scripts/datos/lectores_semilla_con_errores.csv \
--     -f /scripts/carga-lectores.sql
--
-- Sin "-v archivo=..." carga /scripts/datos/lectores_semilla.csv.
-- Repetir la carga no duplica nada: un documento o correo que ya está se rechaza.

\set ON_ERROR_STOP on
\if :{?archivo}
\else
    \set archivo /scripts/datos/lectores_semilla.csv
\endif

SET search_path TO biblioteca, public;

-- crypt() y gen_salt() vienen de pgcrypto; va en public para que
-- DROP SCHEMA biblioteca CASCADE (01_esquema.sql) no se la lleve.
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;

BEGIN;

TRUNCATE stg_linea, stg_lector RESTART IDENTITY;

-- 1. Leer el archivo tal cual, una fila por línea
COPY stg_linea (linea) FROM :'archivo' WITH (FORMAT text);
DELETE FROM stg_linea WHERE n = 1;          -- encabezado

-- 2. Partir cada línea en sus campos. Corregir y cargar: trim a todo y
--    correo en minúsculas (corrección mecánica, no cambia el significado).
INSERT INTO stg_lector (linea_csv, contenido, num_campos,
                        documento, nombres, apellidos, correo, telefono)
SELECT n, linea,
       array_length(string_to_array(linea, ','), 1),
       trim(split_part(linea, ',', 1)),
       trim(split_part(linea, ',', 2)),
       trim(split_part(linea, ',', 3)),
       lower(trim(split_part(linea, ',', 4))),
       trim(split_part(linea, ',', 5))
FROM stg_linea;

-- 3. Validar (la primera regla que falla da el motivo)
UPDATE stg_lector SET motivo = CASE
    WHEN num_campos <> 5                          THEN 'tiene ' || num_campos || ' columnas, se esperaban 5'
    WHEN documento = ''                           THEN 'documento vacío'
    WHEN documento !~ '^[0-9]{6,15}$'             THEN 'documento no numérico o de longitud inválida'
    WHEN nombres = ''                             THEN 'nombres vacío'
    WHEN length(nombres) > 80                     THEN 'nombres de más de 80 caracteres'
    WHEN apellidos = ''                           THEN 'apellidos vacío'
    WHEN length(apellidos) > 80                   THEN 'apellidos de más de 80 caracteres'
    WHEN correo = ''                              THEN 'correo vacío'
    WHEN correo !~ '^[^@ ]+@[^@ ]+\.[^@ ]+$'      THEN 'correo mal formado'
    WHEN length(correo) > 120                     THEN 'correo de más de 120 caracteres'
    WHEN telefono !~ '^[0-9]{7,15}$'              THEN 'teléfono no numérico o de longitud inválida'
    WHEN EXISTS (SELECT 1 FROM lector l WHERE l.documento = stg_lector.documento)
                                                  THEN 'documento ya existe'
    WHEN EXISTS (SELECT 1 FROM usuario u WHERE u.nombre_usuario = stg_lector.documento)
                                                  THEN 'nombre de usuario ya existe'
    WHEN EXISTS (SELECT 1 FROM lector l WHERE l.correo = stg_lector.correo)
                                                  THEN 'correo ya registrado por otro lector'
END;

-- 4. Duplicados dentro del mismo archivo: se conserva la primera aparición
UPDATE stg_lector SET motivo = CASE
    WHEN EXISTS (SELECT 1 FROM stg_lector s2
                 WHERE s2.documento = stg_lector.documento
                   AND s2.motivo IS NULL AND s2.linea_csv < stg_lector.linea_csv)
        THEN 'documento repetido en el archivo'
    ELSE 'correo repetido en el archivo'
END
WHERE motivo IS NULL
  AND EXISTS (SELECT 1 FROM stg_lector s2
              WHERE (s2.documento = stg_lector.documento OR s2.correo = stg_lector.correo)
                AND s2.motivo IS NULL
                AND s2.linea_csv < stg_lector.linea_csv);

-- 5a. Cuenta de acceso: usuario = documento, contraseña inicial = documento con hash
INSERT INTO usuario (nombre_usuario, contrasena_hash, rol)
SELECT documento, crypt(documento, gen_salt('bf')), 'lector'
FROM stg_lector
WHERE motivo IS NULL;

-- 5b. Datos del lector, enlazados a su cuenta por el documento
INSERT INTO lector (id_usuario, documento, nombres, apellidos, correo, telefono)
SELECT u.id_usuario, s.documento, s.nombres, s.apellidos, s.correo, s.telefono
FROM stg_lector s
JOIN usuario u ON u.nombre_usuario = s.documento AND u.rol = 'lector'
WHERE s.motivo IS NULL;

-- 6. Rechazadas a la bitácora
INSERT INTO rechazo_carga (archivo, linea, contenido, motivo)
SELECT :'archivo', linea_csv, contenido, motivo
FROM stg_lector
WHERE motivo IS NOT NULL;

COMMIT;

-- Resumen de la carga
SELECT count(*) FILTER (WHERE motivo IS NULL)     AS cargadas,
       count(*) FILTER (WHERE motivo IS NOT NULL) AS rechazadas
FROM stg_lector;

SELECT linea_csv AS linea, motivo, contenido
FROM stg_lector
WHERE motivo IS NOT NULL
ORDER BY linea_csv;
