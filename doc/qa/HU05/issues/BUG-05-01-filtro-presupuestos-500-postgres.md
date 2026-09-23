# BUG-05-01 — GET /api/Presupuestos?anio=&mes= devuelve 500 (integer out of range) cuando existe un MesAnio por defecto

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Presupuestos] El filtro `?anio=&mes=` devuelve `500 "22003: integer out of range"` si existe algún presupuesto con `MesAnio` en su valor por defecto (0001-01-01)**

## Labels sugeridos
`bug` · `backend` · `PostgreSQL` · `prioridad: alta` · `solo-producción (no reproduce con InMemory)`

## Descripción

El endpoint `GET /api/Presupuestos?anio=2026&mes=9` **revienta con HTTP 500** cuando en la base existe un presupuesto cuyo `MesAnio` quedó en el valor por defecto (`0001-01-01T00:00:00Z`), situación que **la propia API permite crear** (HU-05 CP-12 devuelve `201` cuando no se envía `mesAnio`).

### Causa raíz

- `MesAnio` se mapea a `timestamp with time zone`. PostgreSQL **no puede representar el año 1** de .NET: Npgsql lo guarda como el valor especial **`-infinity`**.
- El filtro original usaba `p.MesAnio.Year == anio && p.MesAnio.Month == mes`, que EF/Npgsql traduce a `date_part('year', col)::int`. Para la fila `-infinity`, `date_part('year', '-infinity')` produce `NaN` y el **cast `::int` lanza `22003: integer out of range`** (SQLSTATE 22003).
- Por eso la suite xUnit (base in-memory) no lo detectó: InMemory evalúa `DateTime.Year` en memoria y no tiene el caso `-infinity`.

### Confirmado empíricamente
- Corrida del 23-sep-2026, ambiente Docker (PostgreSQL 16 + API .NET 8): **HU-05 CP-15**, **FP-08** (Filtros/Paginación) y **PP-03** (Performance) fallaban con `500`.

## Código anterior (bug)

**Archivo:** `Controllers/PresupuestosController.cs` → `GetPresupuestos`

```csharp
if (anio.HasValue && mes.HasValue)
    query = query.Where(p => p.MesAnio.Year == anio.Value && p.MesAnio.Month == mes.Value);
```

## Código corregido (aplicado)

```csharp
if (anio.HasValue && mes.HasValue)
{
    var inicio = new DateTime(anio.Value, mes.Value, 1, 0, 0, 0, DateTimeKind.Utc);
    var fin = inicio.AddMonths(1);
    query = query.Where(p => p.MesAnio >= inicio && p.MesAnio < fin);
}
```

- Comparación por **rango de fechas** en vez de extracción de año/mes: evita `date_part(...)::int` y el caso `NaN`.
- `DateTimeKind.Utc` es obligatorio: Npgsql rechaza params `Kind=Unspecified` contra una columna `timestamptz`.
- Semántica equivalente: devuelve solo el mes solicitado. XUnit sigue en **52/52** tras el cambio.

## Pasos para reproducir (pre-fix)

1. Levantar entorno: `docker compose up -d --build postgres_db backend_api` (base limpia).
2. Registrar un hogar y crear un presupuesto **sin** `mesAnio` (queda `0001-01-01` → `-infinity`):
   ```bash
   curl -X POST http://localhost:8080/api/Presupuestos \
     -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"idCategoria":1,"montoLimite":120.00}'
   ```
3. Filtrar por mes:
   ```bash
   curl -i "http://localhost:8080/api/Presupuestos?anio=2026&mes=9" \
     -H "Authorization: Bearer $TOKEN"
   ```
4. **Resultado obtenido (pre-fix):** `HTTP 500` con body `Npgsql.PostgresException (0x80004005): 22003: integer out of range`.
   **Esperado:** `200` con la lista filtrada.

## Impacto

- **Demo-blocker:** cualquier hogar que tenga 1 presupuesto creado sin `mesAnio` rompe el filtrado de Presupuestos por mes en el frontend.
- Silencioso en desarrollo local si se prueban solo los casos con `mesAnio` presente.

## Recomendado (seguimiento, CONFIRMAR-CON-EQUIPO)

- Evaluar agregar validación para que `MesAnio` sea **obligatorio y válido** en `Create`/`Update` (hoy con `201` acepta el valor por defecto; CP-12 de HU-05 lo documenta como comportamiento real). Si se implementa, agregar un caso de regresión: *"crear presupuesto sin mesAnio → 400"*.

## Entorno verificado
- Rama `qa/ejecucion-suite-tests` (código de `develop`) · .NET 8 · PostgreSQL 16 vía Docker Compose — 2026-09-23
- Casos asociados: **HU-05 CP-15**, **FP-08** (Filtros/Paginación), **PP-03** (Performance)