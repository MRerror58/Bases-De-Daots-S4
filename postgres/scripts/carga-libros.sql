-- Carga de libros desde CSV al esquema biblioteca (S14, Grupo 1)
-- Patrón: tabla de paso -> validación -> tabla final -> bitácora, en una transacción.
--
-- Uso (desde entorno-docker/, con los CSV en postgres/scripts/datos/):
--   docker compose exec postgres psql -U curso -d curso \
--     -v archivo=/scripts/datos/libros_semilla_con_errores.csv \
--     -f /scripts/carga-libros.sql
--
-- Sin "-v archivo=..." carga /scripts/datos/libros_semilla.csv.
-- Repetir la carga no duplica nada: un ISBN que ya está se rechaza.

\set ON_ERROR_STOP on
\if :{?archivo}
\else
    \set archivo /scripts/datos/libros_semilla.csv
\endif

SET search_path TO biblioteca, public;

BEGIN;

TRUNCATE stg_linea, stg_libro RESTART IDENTITY;

-- 1. Leer el archivo tal cual, una fila por línea (el tabulador no aparece en el CSV)
COPY stg_linea (linea) FROM :'archivo' WITH (FORMAT text);
DELETE FROM stg_linea WHERE n = 1;          -- encabezado

-- 2. Partir cada línea en sus campos, todavía como texto
INSERT INTO stg_libro (linea_csv, contenido, num_campos, isbn, titulo, autor,
                       categoria, anio_publicacion, ejemplares_disponibles)
SELECT n, linea,
       array_length(string_to_array(linea, ','), 1),
       trim(split_part(linea, ',', 1)),
       trim(split_part(linea, ',', 2)),
       trim(split_part(linea, ',', 3)),
       trim(split_part(linea, ',', 4)),
       trim(split_part(linea, ',', 5)),
       trim(split_part(linea, ',', 6))
FROM stg_linea;

-- 3. Validar: la primera regla que falla da el motivo.
--    El orden importa: cada ::integer solo se intenta después de comprobar
--    con una expresión regular que el texto son dígitos.
UPDATE stg_libro SET motivo = CASE
    WHEN num_campos <> 6                          THEN 'tiene ' || num_campos || ' columnas, se esperaban 6'
    WHEN isbn = ''                                THEN 'isbn vacío'
    WHEN isbn !~ '^[0-9]{13}$'                    THEN 'isbn no tiene 13 dígitos'
    WHEN titulo = ''                              THEN 'título vacío'
    WHEN length(titulo) > 200                     THEN 'título de más de 200 caracteres'
    WHEN autor = ''                               THEN 'autor vacío'
    WHEN length(autor) > 120                      THEN 'autor de más de 120 caracteres'
    WHEN categoria = ''                           THEN 'categoría vacía'
    WHEN length(categoria) > 40                   THEN 'categoría de más de 40 caracteres'
    WHEN anio_publicacion !~ '^[0-9]{1,4}$'       THEN 'año no numérico'
    WHEN anio_publicacion::integer NOT BETWEEN 1450 AND 2100
                                                  THEN 'año fuera de rango'
    WHEN anio_publicacion::integer > extract(year FROM current_date)
                                                  THEN 'año en el futuro'
    WHEN ejemplares_disponibles !~ '^-?[0-9]{1,6}$'
                                                  THEN 'ejemplares no numérico'
    WHEN ejemplares_disponibles::integer < 0      THEN 'ejemplares negativo'
    WHEN EXISTS (SELECT 1 FROM libro l WHERE l.isbn = stg_libro.isbn)
                                                  THEN 'isbn ya existe en el catálogo'
END;

-- 4. Duplicados dentro del mismo archivo: se conserva la primera aparición
UPDATE stg_libro SET motivo = 'isbn repetido en el archivo (línea '
       || (SELECT min(s2.linea_csv) FROM stg_libro s2
           WHERE s2.isbn = stg_libro.isbn AND s2.motivo IS NULL) || ')'
WHERE motivo IS NULL
  AND EXISTS (SELECT 1 FROM stg_libro s2
              WHERE s2.isbn = stg_libro.isbn
                AND s2.motivo IS NULL
                AND s2.linea_csv < stg_libro.linea_csv);

-- 5. Pasar las filas válidas a libro, ya con su tipo (editorial y activo toman su valor por defecto)
INSERT INTO libro (isbn, titulo, autor, categoria, anio_publicacion, ejemplares_disponibles)
SELECT isbn, titulo, autor, categoria,
       anio_publicacion::smallint, ejemplares_disponibles::integer
FROM stg_libro
WHERE motivo IS NULL;

-- 6. Dejar constancia de las rechazadas
INSERT INTO rechazo_carga (archivo, linea, contenido, motivo)
SELECT :'archivo', linea_csv, contenido, motivo
FROM stg_libro
WHERE motivo IS NOT NULL;

COMMIT;

-- Resumen de la carga
SELECT count(*) FILTER (WHERE motivo IS NULL)     AS cargadas,
       count(*) FILTER (WHERE motivo IS NOT NULL) AS rechazadas
FROM stg_libro;

SELECT linea_csv AS linea, motivo, contenido
FROM stg_libro
WHERE motivo IS NOT NULL
ORDER BY linea_csv;
