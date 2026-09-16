# Casos de Prueba — Filtros y Paginación — RemesaSmart SV
**Proyecto:** RemesaSmart SV — CasaTIC
**Responsable:** Emelie
**Prioridad:** Media
**Fecha:** diseño base contra rama `develop` (endpoints y parámetros confirmados del código real)

> Ends confirmados del código: `MovimientosController.GetMovimientos(categoriaId, tipo)`,
> `PresupuestosController.GetPresupuestos(anio, mes)`, `CategoriasController.GetCategorias()`,
> `MetasAhorroController.GetMetas()`. **Ningún GET implementa paginación** (`page`/`pageSize`
> no existen como parámetros). Los casos de paginación documentan el **comportamiento real** y
> quedan marcados como **CONFIRMAR-CON-EQUIPO** hasta definir los criterios de aceptación.
> Base URL con Docker Compose: `http://localhost:8080`.

## 0. Notas del modelo real y precondiciones
- Se precondicionan: 1 hogar Admin (Carlos), categorías (Alimentación, Salario, Transporte), **30 movimientos** distribuidos entre categorías/tipos/meses, **10 presupuestos** en meses distintos y **3 metas de ahorro**.
- **Filtros de Movimientos:** `?categoriaId=` (int) y `?tipo=` (string, compara **exacta y sensible a mayúsculas**; si viene vacío/espacios se ignora).
- **Filtro de Presupuestos:** solo aplica si llegan **ambos** `?anio=` y `?mes=`; con solo uno de los dos se ignora y devuelve todos.
- **Paginación:** no existe en ningún controlador. Los parámetros `page`/`pageSize` se ignoran y se devuelve el set completo, siempre ordenado (fecha desc / mes desc).

## 1. Filtros — Movimientos (`GET /api/Movimientos`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| FP-01 | Listar sin filtros | GET /api/Movimientos | 200, 30 movimientos del propio hogar, ordenados por Fecha desc | Media |
| FP-02 | Filtrar por categoría | GET /api/Movimientos?categoriaId={IdCatAlimentacion} | 200 solo los de esa categoría | Media |
| FP-03 | Filtrar por categoría inexistente | GET /api/Movimientos?categoriaId=99999 | 200 con lista vacía `[]` | Baja |
| FP-04 | Filtrar por tipo | GET /api/Movimientos?tipo=Gasto | 200 solo `Tipo == "Gasto"` | Media |
| FP-05 | Filtrar por tipo en minúsculas | GET /api/Movimientos?tipo=gasto | 200 vacío (comparación sensible a mayúsculas) — **CONFIRMAR-CON-EQUIPO** | Media |
| FP-06 | Filtrar combinado categoría + tipo | GET /api/Movimientos?categoriaId={id}&tipo=Gasto | 200 intersección de ambos filtros | Media |
| FP-07 | Aislamiento por hogar | GET /api/Movimientos con movimientos de otro hogar sembrados | 200 solo los del hogar del token | Alta |

## 2. Filtros — Presupuestos (`GET /api/Presupuestos`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| FP-08 | Filtrar por año y mes | GET /api/Presupuestos?anio=2026&mes=9 | 200 solo los de 2026-09 | Media |
| FP-09 | Filtrar solo por año | GET /api/Presupuestos?anio=2026 (sin mes) | Comportamiento real: 200 con TODOS (filtro ignorado) — **CONFIRMAR-CON-EQUIPO** | Media |
| FP-10 | Filtrar solo por mes | GET /api/Presupuestos?mes=9 (sin anio) | Comportamiento real: 200 con TODOS — **CONFIRMAR-CON-EQUIPO** | Media |
| FP-11 | Filtrar sin coincidencias | GET /api/Presupuestos?anio=2027&mes=1 | 200 con lista vacía `[]` | Baja |
| FP-12 | Aislamiento por hogar | GET /api/Presupuestos con presupuestos de otro hogar | 200 solo del hogar del token, ordenados por MesAnio desc | Alta |

## 3. Paginación (comportamiento real: NO existe)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| FP-13 | Movimientos con page/pageSize | GET /api/Movimientos?page=1&pageSize=10 | Comportamiento real: 200 con TODOS los movimientos (params ignorados) — **CONFIRMAR-CON-EQUIPO** | Media |
| FP-14 | Presupuestos con page/pageSize | GET /api/Presupuestos?page=2&pageSize=5 | Comportamiento real: 200 con TODOS — **CONFIRMAR-CON-EQUIPO** | Media |
| FP-15 | Categorías con page/pageSize | GET /api/Categorias?page=1&pageSize=20 | Comportamiento real: 200 con TODAS las categorías ordenadas por nombre — **CONFIRMAR-CON-EQUIPO** | Media |
| FP-16 | Metas de ahorro | GET /api/MetasAhorro (3 metas sembradas) | 200 con las 3 (sin paginación; sin campo total/páginas) — **CONFIRMAR-CON-EQUIPO** | Baja |
| FP-17 | Parámetros inválidos de paginación | GET /api/Movimientos?page=-1&pageSize=abc | Comportamiento real: 200 con TODOS o 400 según binding (no existe contrato de paginación) — **CONFIRMAR-CON-EQUIPO** | Baja |

## Resumen
- Total de casos: **17** (`FP-01` a `FP-17`).
- Cobertura: filtros funcionales de Movimientos (categoría, tipo, combinados, caso sensible, aislamiento), filtros de Presupuestos (anio+mes, comportamiento con un solo parámetro, sin coincidencias, aislamiento) y comportamiento real de paginación en las 4 listas principales.
- **Hallazgo principal a validar con el equipo:** el backend **no implementa paginación** (FP-13 a FP-17); cada listado devuelve el set completo. Si alguna lista puede crecer mucho (movimientos), esto es un riesgo de rendimiento — ver batería `PERF`.