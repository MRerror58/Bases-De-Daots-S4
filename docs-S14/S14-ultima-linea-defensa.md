# S14 · Prueba de la última línea de defensa

## Qué se hizo

1. En una copia temporal de `carga-libros.sql` se comentó la regla del `CASE` de ejemplares negativos:
   `WHEN ejemplares_disponibles::integer < 0 THEN 'ejemplares negativo'`.
2. Se cargó un archivo con 4 filas: 3 libros válidos (`9780000000201` a `9780000000203`) y 1 con `ejemplares_disponibles = -3` (`9780000000204`).
3. Se restauró la regla: la copia temporal se borró y `carga-libros.sql` nunca se modificó.

La salida completa está en `S14-salida-ultima-linea-defensa.txt`.

## Qué pasó

La fila mala pasó la validación (la regex de "ejemplares no numérico" acepta números negativos y la regla que los atrapaba estaba comentada). Llegó al `INSERT INTO libro` y chocó con el `CHECK` del esquema:

```
ERROR:  new row for relation "libro" violates check constraint "libro_ejemplares_disponibles_check"
DETAIL:  Failing row contains (9780000000204, Relato con ejemplares negativos, Autor de Prueba, Novela, null, 2015, -3, t).
```

| Medida | Antes | Después |
|---|---|---|
| Filas en `libro` | 37 | 37 |
| Filas en `rechazo_carga` | 17 | 17 |
| Libros del archivo en `libro` | 0 | 0 |

## ¿Qué pasa con las demás filas de esa carga?

**Ninguna entra, ni siquiera las 3 válidas.** El `INSERT` es una sola sentencia y la carga corre dentro de `BEGIN … COMMIT`. Al fallar una fila, se aborta la sentencia, `ON_ERROR_STOP` detiene el script y la transacción se deshace completa. Con una sola fila mala sin atrapar se pierde toda la carga: es el mismo problema "todo o nada" del `COPY` directo.

## ¿Y con la bitácora?

**Queda igual (17 → 17): no registra nada.** El `INSERT INTO rechazo_carga` va después del que falla, así que nunca se ejecutó; y aunque se hubiera ejecutado, el rollback lo habría deshecho. Tampoco quedan datos en las tablas de paso, porque el `TRUNCATE` del inicio también se revierte. La fila mala no deja rastro: el único aviso es el mensaje de error de PostgreSQL.

## Conclusión

- Sin la regla, la restricción del esquema protege la integridad de los datos: el valor `-3` no llega a `libro`.
- Pero lo hace al costo de la carga entera, y con un mensaje del motor (`libro_ejemplares_disponibles_check`) en vez de uno del negocio, sin el número de línea del archivo.
- Por eso las restricciones son la **última** línea de defensa y no el validador de la carga: la validación debe atrapar cada fila antes, para rechazar solo esa fila, con su motivo, y dejar entrar las demás.
