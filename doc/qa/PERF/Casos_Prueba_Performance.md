# Casos de Prueba — Performance Básica — RemesaSmart SV
**Proyecto:** RemesaSmart SV — CasaTIC
**Responsable:** Emelie
**Prioridad:** Media
**Fecha:** diseño base contra rama `develop` (endpoints confirmados del código real)

> Alcance: **pruebas de performance básicas** (no carga, no estrés). Miden tiempos de respuesta
> de los endpoints de consulta/escritura más usados con un volumen de datos realista sembrado
> vía API. Umbrales iniciales en modo **informativos** (línea base) hasta definir criterios de
> aceptación oficiales de rendimiento con el equipo.
>
> Contraste de código: `MovimientosController`, `PresupuestosController`, `CategoriasController`,
> `Categorias`, `Movimiento`, `Presupuesto` (rama `develop`). Base URL con Docker Compose:
> `http://localhost:8080`.

## 0. Precondiciones y metodología
- Entorno integrado levantado (`docker compose up -d --build postgres_db backend_api`) sobre una **base limpia**.
- Se siembran los datos vía API (herramientas de volumen): 1 hogar Admin, **50 categorías**, **N movimientos** (predeterminado 1.000) y **N presupuestos** (predeterminado 200). Todo es configurable por parámetros del script.
- Cada caso medido con **5 repeticiones**; se reporta **promedio**, **p95** y **p99** (ms). El resultado PASO/FALLO se evalúa contra el **p95**.
- Umbrales predeterminados:
  | Métrica | Umbral de alerta (p95) |
  |---|---|
  | Lecturas GET sin filtros / con filtros | < 500 ms |
  | GET con volumen alto (10.000 registros) | < 1.000 ms |
  | Escritura POST /api/Movimientos | < 500 ms |
  | Login POST /api/Auth/login | < 500 ms |
  | Creación masiva 1.000 movimientos | < 90 s **global** |

> ⚠️ Los números obtenidos dependen de la máquina y del entorno (Docker Dev en local). No son SLA; son **línea base** para vigilar regresiones.

## 1. Consulta (`GET`)

| ID | Descripción | Endpoint | Umbral esperado (p95) | Prioridad |
|----|-------------|----------|----------------------|-----------|
| PP-01 | Listar movimientos (volumen sembrado, predet. 1.000) | GET /api/Movimientos (autenticado) | < 500 ms y respuesta con el total sembrado | Media |
| PP-02 | Listar movimientos filtrados por categoría + tipo | GET /api/Movimientos?categoriaId={id}&tipo=Gasto | < 500 ms y respuesta coherente con el filtro | Media |
| PP-03 | Listar presupuestos filtrados por anio+mes (200 registros) | GET /api/Presupuestos?anio=2026&mes=9 | < 500 ms y respuesta filtrada | Media |
| PP-04 | Listar categorías (50 registros) | GET /api/Categorias | < 300 ms | Media |
| PP-05 | Listar movimientos con 10.000 registros (volumen alto) | GET /api/Movimientos | < 1.000 ms (ojo: sin paginación devuelve todo el conjunto) | Media ⚠️ |

> ⚠️ PP-05 cruza con el hallazgo de `FILTROS-PAGINACION`: el backend **no tiene paginación**, por lo que con 10.000 registros la respuesta crece en tamaño; el umbral mide el riesgo de degradación.

## 2. Escritura (`POST`)

| ID | Descripción | Endpoint | Umbral esperado (p95) | Prioridad |
|----|-------------|----------|----------------------|-----------|
| PP-06 | Crear un movimiento válido | POST /api/Movimientos `{IdCategoria, Monto, Fecha, Tipo}` | < 500 ms | Media |
| PP-07 | Crear 1.000 movimientos de forma secuencial | POST /api/Movimientos × 1.000 | **Tiempo global < 90 s** (≈ 90 ms/op en promedio) | Media |
| PP-08 | Login con credenciales válidas | POST /api/Auth/login `{Correo, Contrasena}` | < 500 ms | Media |

> Para ver PP-02 con más volumen y PP-05, ejecutar con `-Movimientos 5000` y `-Movimientos 10000` respectivamente (aumenta el tiempo de siembra).

## Resumen
- Total de casos: **8** (`PP-01` a `PP-08`).
- Cobertura: lectura sin filtros, lectura con filtros, lectura con volumen alto, listados auxiliares, escritura puntual, escritura masiva y autenticación.
- Entregables de ejecución: `resultados_PERF.csv` / `.json` (maquinable) y `evidencia_raw.log`.
- **Hallazgo transversal a vigilar:** al no existir paginación, `GET /api/Movimientos` devuelve todo el set; los tiempos de PP-01/PP-05 crecerán con el tamaño de datos (ver batería de `FILTROS-PAGINACION` para confirmar con el equipo).