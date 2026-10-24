# S14 · Mapeo CSV → esquema y criterios por tipo de error

Grupo 1. Esquema: `postgres/init/01_esquema.sql`. Scripts: `postgres/scripts/carga-libros.sql` y `carga-lectores.sql`.

## 1. Mapeo CSV → esquema

### `libros_semilla.csv` → `biblioteca.libro`

| Columna del CSV | Tabla.columna destino | Transformación | Regla de validación (motivo en la bitácora) |
|---|---|---|---|
| `isbn` | `libro.isbn` | `trim` | no vacío ("isbn vacío"); exactamente 13 dígitos ("isbn no tiene 13 dígitos"); no existe ya en `libro` ("isbn ya existe en el catálogo"); no repetido antes en el mismo archivo ("isbn repetido en el archivo (línea N)") |
| `titulo` | `libro.titulo` | `trim` | no vacío ("título vacío"); máximo 200 caracteres |
| `autor` | `libro.autor` | `trim` | no vacío ("autor vacío"); máximo 120 caracteres |
| `categoria` | `libro.categoria` | `trim` | no vacía ("categoría vacía"); máximo 40 caracteres |
| `anio_publicacion` | `libro.anio_publicacion` | `trim`, `::smallint` | 1 a 4 dígitos ("año no numérico"); entre 1450 y 2100 ("año fuera de rango"); no mayor al año actual ("año en el futuro") |
| `ejemplares_disponibles` | `libro.ejemplares_disponibles` | `trim`, `::integer` | entero ("ejemplares no numérico"); mayor o igual a 0 ("ejemplares negativo") |
| *(no viene en el CSV)* | `libro.editorial` | queda `NULL` | — |
| *(no viene en el CSV)* | `libro.activo` | valor por defecto `true` | — |
| *(toda la línea)* | — | `num_campos` | exactamente 6 campos ("tiene N columnas, se esperaban 6") |

### `lectores_semilla.csv` → `biblioteca.usuario` + `biblioteca.lector`

Cada lector válido genera **dos filas**: su cuenta de acceso y sus datos personales.

| Columna del CSV | Tabla.columna destino | Transformación | Regla de validación (motivo en la bitácora) |
|---|---|---|---|
| `documento` | `lector.documento` y también `usuario.nombre_usuario` | `trim` | no vacío ("documento vacío"); 6 a 15 dígitos ("documento no numérico o de longitud inválida"); no existe en `lector` ("documento ya existe"); no existe como `nombre_usuario` ("nombre de usuario ya existe"); no repetido en el archivo ("documento repetido en el archivo") |
| `nombres` | `lector.nombres` | `trim` | no vacío ("nombres vacío"); máximo 80 caracteres |
| `apellidos` | `lector.apellidos` | `trim` | no vacío ("apellidos vacío"); máximo 80 caracteres |
| `correo` | `lector.correo` | `trim` y `lower` | no vacío ("correo vacío"); formato `x@y.z` ("correo mal formado"); máximo 120 caracteres; no registrado por otro lector ("correo ya registrado por otro lector"); no repetido en el archivo ("correo repetido en el archivo") |
| `telefono` | `lector.telefono` | `trim` | 7 a 15 dígitos ("teléfono no numérico o de longitud inválida") |
| *(se genera)* | `usuario.contrasena_hash` | `crypt(documento, gen_salt('bf'))` (pgcrypto, bcrypt) | — |
| *(se genera)* | `usuario.rol` | constante `'lector'` | — |
| *(se obtiene al insertar)* | `lector.id_usuario` | se une `usuario.nombre_usuario = documento` | — |
| *(no viene en el CSV)* | `lector.direccion` | queda `NULL` | — |
| *(no viene en el CSV)* | `lector.fecha_registro`, `lector.activo` | valores por defecto (`CURRENT_DATE`, `true`) | — |
| *(toda la línea)* | — | `num_campos` | exactamente 5 campos ("tiene N columnas, se esperaban 5") |

**Contraseña inicial:** el CSV no la trae. Se usa el documento como contraseña inicial, guardada siempre con hash bcrypt (nunca en texto plano). Queda pendiente para el Hito 5 que el sistema obligue a cambiarla en el primer ingreso.

## 2. Criterios por tipo de error

Criterio general: **rechazar y registrar** lo que falta o no se puede adivinar; **corregir y cargar** solo lo que se arregla de forma mecánica sin cambiar el significado; **no actualizar** registros existentes, porque estos archivos son altas y no actualizaciones. Todo rechazo queda en `biblioteca.rechazo_carga` con archivo, línea, contenido original y motivo.

### Los 14 errores de los archivos del curso

| # | Archivo y fila | Problema | Qué se hace | Por qué | Motivo registrado |
|---|---|---|---|---|---|
| 1 | libros · `9780000000001` | ISBN ya existe en el catálogo | Rechazar | Un ISBN es la clave del libro. El archivo es un alta, no una actualización; sobrescribir cambiaría datos sin que nadie lo decida | isbn ya existe en el catálogo |
| 2 | libros · `9780000000033` | título vacío | Rechazar | No se puede inventar el título | título vacío |
| 3 | libros · `9780000000034` | campo numérico con texto (`dos`) | Rechazar | No se adivina el número. En este archivo el `dos` está en la columna del año, por eso el motivo es el del año | año no numérico |
| 4 | libros · `9780000000035` | año `MCMXLIX` | Rechazar | Convertir números romanos no es una corrección mecánica segura | año no numérico |
| 5 | libros · `9780000000036` | una columna de más | Rechazar | No se sabe cuál campo sobra; cargarla correría las columnas | tiene 7 columnas, se esperaban 6 |
| 6 | libros · `9780000000037` | autor vacío | Rechazar | Dato obligatorio que no se puede adivinar | autor vacío |
| 7 | libros · *(isbn vacío)* | ISBN vacío | Rechazar | Sin clave no hay libro | isbn vacío |
| 8 | libros · `9780000000038` | ejemplares negativo (`-3`) | Rechazar | Es un número válido pero sin sentido de negocio | ejemplares negativo |
| 9 | lectores · `1000000001` | documento ya existe | Rechazar | El documento identifica al lector; el archivo es un alta | documento ya existe |
| 10 | lectores · `1000000021` | correo vacío | Rechazar | El correo es obligatorio y único; se usa para notificar la mora | correo vacío |
| 11 | lectores · `1000000022` | correo sin `@` | Rechazar | No se adivina el correo correcto | correo mal formado |
| 12 | lectores · `1000000023` | teléfono no numérico (`tres-cero-cero`) | Rechazar | No se convierte texto a número de teléfono | teléfono no numérico o de longitud inválida |
| 13 | lectores · *(documento vacío)* | documento vacío | Rechazar | Sin documento no hay lector ni cuenta | documento vacío |
| 14 | lectores · `1000000025` | nombres vacío | Rechazar | Dato obligatorio | nombres vacío |

### Errores que agrega el grupo (CSV propio, `libros_propio.csv`)

| # | Problema | Qué se hace | Por qué | Motivo registrado |
|---|---|---|---|---|
| 15 | El mismo ISBN dos veces en el archivo | Se conserva la primera aparición y se rechazan las demás | El `EXISTS` contra la tabla no lo ve porque ninguna de las dos está aún en `libro`. Se cuenta como duplicado, no como libro nuevo | isbn repetido en el archivo (línea 4) |
| 16 | Año en el futuro (`2077`) | Rechazar | El esquema lo aceptaría (el `CHECK` llega hasta 2100). La carga agrega la regla de negocio: no mayor al año actual | año en el futuro |
| 17 | ISBN de 12 dígitos | Rechazar | No se completa con un dígito inventado | isbn no tiene 13 dígitos |

### Correcciones automáticas (no se rechazan)

| Caso | Qué se hace | Por qué |
|---|---|---|
| Espacios al inicio o al final de cualquier campo | `trim` y cargar | La corrección es mecánica y no cambia el significado |
| Correo con mayúsculas (`Ana@X.co`) | `lower` y cargar | Evita lectores duplicados por la capitalización. Dos filas que difieren solo en mayúsculas se tratan como el mismo correo |

### Limitaciones conocidas

- Una coma dentro de comillas (`"Libro, con coma"`) parte la fila en un campo de más, y se rechaza por tener 7 columnas.
- Un archivo guardado con `;` rechaza todas las filas con "tiene 1 columnas…", que es la pista para revisar el separador.
- Los finales de línea de Windows (CRLF) se leen bien.
