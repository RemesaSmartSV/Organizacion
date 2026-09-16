# Performance básica — RemesaSmart SV

**Responsable:** Emelie · **Rol:** QA
**Prioridad:** Media
**Alcance:** Pruebas de performance básicas (linea base de tiempos de respuesta) sobre los endpoints de mayor uso, con volumen de datos sembrado vía API.

---

## Estado

> **Batería de API pendiente de ejecución** (requiere el entorno Docker arriba en `http://localhost:8080`; no estaba disponible al preparar esta entrega).
> En cambio, la **batería xUnit** (`PerformanceTests.cs`) **sí se ejecutó** y pasó (4/4) contra la base *in-memory*; esos tiempos quedaron registrados como linea base local en la sección de abajo.

## Entregables de esta carpeta

| Archivo | Descripción |
|---------|-------------|
| `Casos_Prueba_Performance.md` | Diseño de los 8 casos (`PP-01` a `PP-08`) con umbrales (entrada del proceso) |
| `Ejecutar_Pruebas_Performance.ps1` | Script re-ejecutable que siembra datos vía API, mide tiempos (promedio/p95/p99) y genera reporte |
| `../../../doc/qa/backend-tests/PerformanceTests.cs` | Batería xUnit de medición básica sobre base in-memory (ya ejecutada) |
| `resultados_PERF.csv` / `.json` | Generados por el script al ejecutarse (maquinable) |
| `evidencia_raw.log` | Request/response cruda (generado por el script) |

## Linea base local (xUnit, base in-memory — 12 sept 2026)

| Escenario | Datos | Tiempo medido (in-memory) |
|---|---|---|
| GET /api/Movimientos (sin filtro) | 2.000 | 8 ms |
| GET /api/Movimientos (filtro categoria+tipo) | 10.000 | 168 ms |
| POST /api/Movimientos × 1.000 (secuencial) | 1.000 | 3.599 ms |
| GET /api/Presupuestos (filtro anio+mes) | 2.000 | 10 ms |

> ⚠️ Los tiempos in-memory **no** representan el rendimiento real con PostgreSQL; solo detectan regresiones groseras y validan la lógica. La métrica válida es la del script de API.

## Cómo ejecutar la batería de API

```powershell
# 1. Levantar entorno (requiere Docker Desktop) sobre base limpia
cd backend
docker compose up -d --build postgres_db backend_api
docker compose down -v   # si ya existía una base con datos previos

# 2. Esperar ~30 s y ejecutar (volúmenes por defecto)
cd ..
powershell -ExecutionPolicy Bypass -File doc\qa\PERF\Ejecutar_Pruebas_Performance.ps1

# 3. Variantes
powershell -ExecutionPolicy Bypass -File doc\qa\PERF\Ejecutar_Pruebas_Performance.ps1 -Movimientos 5000 -Repeticiones 3
powershell -ExecutionPolicy Bypass -File doc\qa\PERF\Ejecutar_Pruebas_Performance.ps1 -Movimientos 10000   # activa PP-05
```

## Parámetros del script

| Parámetro | Default | Descripción |
|-----------|---------|-------------|
| `-Movimientos` | 1000 | Movimientos a sembrar (>= 10000 activa PP-05) |
| `-Presupuestos` | 200 | Presupuestos a sembrar |
| `-Categorias` | 50 | Categorías a sembrar |
| `-Repeticiones` | 5 | Iteraciones por caso para calcular promedio/p95/p99 |
| `-UmbralLectura` | 500 ms | Umbral p95 de lecturas |
| `-UmbralVolumenAlto` | 1000 ms | Umbral p95 de volumen alto |
| `-UmbralEscritura` | 500 ms | Umbral p95 de escritura/login |
| `-UmbralMasivaMs` | 90000 ms | Umbral global de la siembra masiva (PP-07) |
| `-Base` | http://localhost:8080 | URL base de la API |

## Notas para el equipo

- Los umbrales son **sugeridos / línea base**; falta definir criterios de aceptación oficiales de rendimiento.
- **Hallazgo transversal:** el backend no tiene paginación, por lo que `GET /api/Movimientos` devuelve siempre el set completo; el tiempo de respuesta crecerá con la base de datos. Ver batería `../FILTROS-PAGINACION`.
- Los correos de la siembra son aleatorios por ejecución; no chocan entre corridas, pero la base debe estar limpia para que los conteos de PP-01 coincidan.