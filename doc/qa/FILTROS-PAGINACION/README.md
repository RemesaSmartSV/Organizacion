# Filtros y Paginación — RemesaSmart SV

**Responsable:** Emelie · **Rol:** QA
**Prioridad:** Media
**Alcance:** Verificación funcional de los filtros existentes (`Movimientos`, `Presupuestos`) y documentación del comportamiento real en cuanto a **paginación** (el backend NO la implementa actualmente).

---

## Estado

> **Batería de API pendiente de ejecución** (requiere el entorno Docker arriba en `http://localhost:8080`).
> La **batería xUnit** (`FiltrosPaginacionTests.cs`) **sí se ejecutó** y pasó (9/9), verificando el comportamiento real en memoria:
> - Filtros de Movimientos: combinado categoría+tipo, categoría inexistente → `[]`, tipo con espacios → ignora el filtro.
> - Filtros de Presupuestos: anio+mes → solo ese mes; solo anio / solo mes → devuelve todos (filtro ignorado); sin coincidencias → `[]`.
> - Paginación: `GetMovimientos` y `GetPresupuestos` devuelven **todo** el conjunto (no existen `page`/`pageSize`).

## Entregables de esta carpeta

| Archivo | Descripción |
|---------|-------------|
| `Casos_Prueba_Filtros_Paginacion.md` | Diseño de los 17 casos (`FP-01` a `FP-17`) (entrada del proceso) |
| `Ejecutar_Pruebas_Filtros_Paginacion.ps1` | Script re-ejecutable de la batería contra la API |
| `../../../doc/qa/backend-tests/FiltrosPaginacionTests.cs` | Batería xUnit del comportamiento real (ya ejecutada) |
| `resultados_FILTROS_PAGINACION.csv` / `.json` | Resultados maquinables (generados al ejecutar el script) |
| `evidencia_raw.log` | Request/response cruda (generado por el script) |

## Cómo ejecutar la batería de API

```powershell
# 1. Levantar entorno (requiere Docker Desktop) sobre base limpia
cd backend
docker compose up -d --build postgres_db backend_api
docker compose down -v   # si ya existía una base con datos previos

# 2. Esperar ~30 s y ejecutar
cd ..
powershell -ExecutionPolicy Bypass -File doc\qa\FILTROS-PAGINACION\Ejecutar_Pruebas_Filtros_Paginacion.ps1
```

El script siembra su propio hogar (correos aleatorios por corrida), así que puede re-ejecutarse sin limpiar la base entre corridas.

## Hallazgo principal (CONFIRMAR-CON-EQUIPO)

> **El backend no implementa paginación en ningún listado.** Todas las listas (`/api/Movimientos`, `/api/Presupuestos`, `/api/Categorias`, `/api/MetasAhorro`) devuelven el set completo sin `total`/páginas, y los parámetros `page`/`pageSize` se ignoran (FP-13 a FP-17).

Acciones sugeridas según decisión del equipo:
1. **Si es un defecto:** crear issue "Faltante: paginación de listados (movimientos)" — a mayor volumen de movimientos mayor latencia (ver `../PERF`, sin paginación la respuesta crece).
2. **Si es aceptable para el MVP:** cerrar como *works as designed* y actualizar los casos FP-13..FP-17 a su comportamiento esperado oficial.

## Otros hallazgos menores
- `?tipo=gasto` (minúsculas) devuelve vacío: la comparación del filtro de Movimientos es **sensible a mayúsculas** (FP-05).
- El filtro de Presupuestos exige **anio y mes juntos**; un solo parámetro se ignora y devuelve todo (FP-09, FP-10).