# Entrega — Ejecución del flujo completo de la demo end-to-end · RemesaSmart SV

**Responsable:** Emelie · **Rol:** QA
**Alcance:** los 10 pasos de la demo en vivo del guion de presentación
(`doc/guion-presentacion.md`, sección 8) ejecutados contra la API real en Docker + PostgreSQL 16
**Componente:** `backend/` (ASP.NET Core Web API .NET 8) · el frontend es un repo aparte, no versionado aquí
**Fecha de ejecución:** domingo 27 de septiembre de 2026
**Método:** 40 comprobaciones automatizadas y re-ejecutables contra la API levantado

---

## Resultado en una línea

> **11 pasos de la demo · 28/40 comprobaciones en verde · 12 en rojo · 3 pasos se caen en silencio si el frontend no los compensa · 11 hallazgos nuevos (3 bloqueantes de la demo)**

| | Detalle |
|---|---|
| Comprobaciones | 40 (28 PASO · 12 FALLO) |
| Pasos de la demo que se sostienen solo con la API | 3 de 11 |
| Hallazgos **nuevos** documentados | 11 (`DEMO-01` … `DEMO-11`) |
| Hallazgos **previos confirmados** en ejecución real | 5 (`BUG-01`, `SEC-03`, `SEC-07`, `SEC-08`, y `BUG-05` como regresión verde) |
| Regresión verificada como **corregida** | `BUG-05` (filtro de presupuestos) → 200 OK contra PostgreSQL real |

**Dos espacios de identificadores, a propósito:** los **issues** de esta entrega son `DEMO-01` … `DEMO-11` (un
archivo cada uno en `issues/`), y los **casos de prueba** del script son `CP-D01` … `CP-D40` (filas de
`resultados_DEMO_E2E.csv`). Se numeran aparte para no confundir "el check que falló" con "el issue a abrir".

## Entorno usado

| Componente | Versión / estado |
|---|---|
| Docker Desktop | 29.7.2 (WSL2) |
| PostgreSQL | 16 (contenedor `postgres:16-alpine`) |
| API | .NET 8 en `http://localhost:8080` |
| SDK de build local | 10.0.302 (el proyecto apunta a `net8.0` y el `Dockerfile` usa SDK 8; ver `DEMO-11`) |
| Frontend | **ausente** — el repo `frontend/` no está clonado (ver `DEMO-01`) |

## Veredicto por paso de la demo

| # | Paso del guion | Resultado | Nota |
|---|---|---|---|
| 1 | `docker compose up --build` | ⚠️ 1/2 | **El comando documentado falla**: el servicio `frontend_web` no encuentra `../frontend` → `DEMO-01` |
| 2 | Registro: hogar + Admin en una llamada | ✅ 4/4 | Promesa cumplida. Los tildes y la eñe de "María López" se guardan y se devuelven intactos |
| 2b | Login y JWT | ⚠️ 2/4 | La sesión dura 8 h, pero el claim de rol no es `role` y falta `iat` → `BUG-01` |
| 3 | Agregar miembro con rol `Miembro` | ✅ 3/3 | Alta, login y aislamiento por hogar correctos |
| 4 | Remesa de $400 con entidad emisora | ✅ 4/4 | `origenEmisora` persistente y con UTF-8 correcto, pero `Tipo` es texto libre → `DEMO-05` |
| 5 | Gasto de alimentación de $120 | ✅ 2/2 | Correcto |
| 6 | Tablero: flujo, distribución y saldo | ⚠️ 2/3 | Los números se derivan bien y sin error de redondeo, pero **no hay endpoint de tablero** y no hay forma de identificar una remesa → `DEMO-07`, `DEMO-08` |
| 7 | Presupuesto de $300 → barra 40% | ⚠️ 3/4 | El 40% es correcto, pero **la API no devuelve el consumo** → `DEMO-06` |
| 8 | Gasto de $200 más → **aparece la alerta** | ⚠️ 2/3 | El exceso se detecta en los datos, pero **no hay alerta en la API** → `DEMO-04` ⚠️ *momento clave de la demo* |
| 9 | Meta de $2,000 a 6 meses + aporte | ⚠️ 5/6 | El aporte y el cambio de estado automático funcionan; **el ritmo mensual no lo entrega la API** → `DEMO-09` |
| 10 | Educación Financiera: tip relacionado | ❌ 0/2 | **La sección sale vacía**: no hay contenido sembrado → `DEMO-02` |
| 11 | Cierre de sesión y token invalidado | ❌ 0/3 | El token sigue vivo 8 h, sin cabeceras de seguridad y con Swagger abierto → `SEC-07`, `SEC-03`, `SEC-08` |

## Los 3 problemas que pueden hacer fracasar la demo

1. **`DEMO-01` — el comando de arranque documentado no funciona.** `docker compose up --build` es el paso 1 del guion y del checklist, y aborta con `path "…\frontend" not found`. Hay que levantar solo `postgres_db backend_api` y el frontend por separado. Si el jurado ve el comando fallar, el punto 1 del arranque se pierde.
2. **`DEMO-02` — Educación Financiera sale vacía.** `GET /api/TipsFinancieros` devuelve `0` filas: la migración `InitialCreate` no siembra ningún tip. El paso 10 del guion pide "abrir Educación Financiera y mostrar el tip relacionado con la actividad de la familia" y no hay nada que mostrar.
3. **`DEMO-04` — la alerta de presupuesto excedido no existe en la API.** Es el momento que el guion marca como *"el momento clave de la demo: hacer pausa aquí"*. La API no expone campo, endpoint ni código HTTP que indique el exceso: depende 100% de que el frontend lo detecte.

## Qué se hizo

1. **Se levantó el entorno real** con `docker compose up -d --build postgres_db backend_api` y se verificó el arranque desde volumen limpio.
2. **Se tradujo la demo a 40 comprobaciones** (`CP-D01` … `CP-D40`) con esperado / obtenido, cubriendo los 10 pasos más el cierre de sesión.
3. **Se distingue entre bug de código y riesgo de demostración**: los checks cuyo esperado es "la API entrega X" fallan cuando el dato lo tiene que calcular el frontend. No son bugs del backend, pero son riesgos reales para la presentación y quedan anotados como tales.
4. **Se revalidaron los hallazgos previos** contra la API viva, sin repetir la auditoría completa: `BUG-01`, `SEC-03`, `SEC-07` y `SEC-08` se reproducen; `BUG-05` se confirma corregido.
5. **Ningún cambio en el código del backend.** La auditoría y esta entrega reportan; las correcciones son PR del equipo de desarrollo.

## Contenido de esta carpeta

| Archivo | Descripción |
|---|---|
| `Ejecutar_Demo_E2E.ps1` | Script re-ejecutable de los 40 checks contra `http://localhost:8080` |
| `resultados_DEMO_E2E.csv` / `.json` | Resultados maquinables de la corrida del 27-09-2026 |
| `evidencia_raw.log` | Request/response crudas de la corrida. **No se versiona** (ver nota) |
| `issues/DEMO-01..DEMO-11` | Un archivo por hallazgo nuevo, listo para crear el issue en GitHub |

> **`evidencia_raw.log` es local, a propósito.** El `.gitignore` de este repositorio excluye `*.log` y en este
> caso conviene: el log guarda los tokens de sesión tal como los devolvió la API, y la clave que los firma
> está versionada en el repositorio del backend (`SEC-01`). Subir esos tokens allowaría falsificar sesiones de
> Admin. La evidencia que sí viaja en el PR es el CSV/JSON de resultados y los fragmentos citados dentro de
> cada issue. Para regenerarlo local, corre el script; para compartirlo, enmascara los `Bearer` antes.

## Cómo reproducir la ejecución

```powershell
# 1. Levantar el entorno (el frontend no es necesario para esta bateria)
cd backend
docker compose up -d --build postgres_db backend_api

# 2. Esperar ~20 s a que la API responda y ejecutar la bateria
cd ..
powershell -ExecutionPolicy Bypass -File doc\qa\DEMO-E2E\Ejecutar_Demo_E2E.ps1
```

El script siembra su propia familia (correos con timestamp), así que es re-ejecutable sin limpiar la base entre corridas.
**Requiere que el `.ps1` se guarde en UTF-8 con BOM**: PowerShell 5.1 lee sin BOM como ANSI y destroza los acentos de "María López" y "Tío Carlos", lo que hace fallar las comparaciones de cadenas con tilde.

## Findings nuevos vs. hallazgos ya conocidos

| ID | Hallazgo | Severidad | Estado |
|---|---|---|---|
| [DEMO-01](issues/DEMO-01-compose-up-build-falla-sin-frontend.md) | `docker compose up --build` falla: falta el contexto `../frontend` | 🔴 Alta | Nuevo — bloqueante |
| [DEMO-02](issues/DEMO-02-educacion-financiera-sin-contenido-sembrado.md) | Educación Financiera sin contenido: la migración no siembra tips | 🔴 Alta | Nuevo — bloqueante |
| [DEMO-03](issues/DEMO-03-api-cae-al-arrancar-en-base-limpi.md) | La API se cae en el primer arranque en base limpia (migración sin reintento) | 🔴 Alta | Nuevo |
| [DEMO-04](issues/DEMO-04-sin-alerta-de-presupuesto-excedido.md) | La API no entrega alerta de presupuesto excedido | 🟠 Alta | Nuevo — bloqueante del momento clave |
| [DEMO-05](issues/DEMO-05-tipo-de-movimiento-sin-validacion.md) | `Movimiento.Tipo` sin lista blanca: una remesa se puede guardar como `Gasto` | 🟡 Media | Nuevo (mismo patrón que `BUG-03`) |
| [DEMO-06](issues/DEMO-06-presupuesto-sin-montogastado-ni-porcentaje.md) | `Presupuesto` no expone consumo ni porcentaje | 🟡 Media | Nuevo |
| [DEMO-07](issues/DEMO-07-sin-endpoint-de-tablero-o-resumen.md) | No hay endpoint de tablero/resumen | 🟡 Media | Nuevo |
| [DEMO-08](issues/DEMO-08-remesa-solo-por-convencion-de-origenemisora.md) | La remesa solo se distingue por convención de `origenEmisora` | 🟡 Media | Nuevo |
| [DEMO-09](issues/DEMO-09-meta-sin-faltante-ni-ritmo-mensual.md) | `MetaAhorro` no expone faltante ni ritmo mensual | 🟡 Media | Nuevo |
| [DEMO-10](issues/DEMO-10-sin-servicio-de-tips.md) | No hay servicio de tips: `EducacionFinanciera` depende de una `Categoria` por hogar | 🟡 Media | Nuevo |
| [DEMO-11](issues/DEMO-11-conflicto-de-version-efcore-y-sdk-sin-fijar.md) | Conflicto `EF Core.Relational` 8.0.11 vs 8.0.30 y SDK local sin fijar | 🟢 Baja | Nuevo |

### Hallazgos previos confirmados en esta corrida

| Hallazgo previo | Check | Resultado |
|---|---|---|
| [BUG-01](../HU01/issues/BUG-01-jwt-sin-claim-role-corto.md) — claim de rol con URI largo y sin `iat` | `CP-D08`, `CP-D10` | ❌ Se reproduce |
| [SEC-03](../SEGURIDAD/issues/SEC-03-sin-cabeceras-de-seguridad.md) — sin cabeceras de seguridad | `CP-D39` | ❌ Se reproduce (0 de 4) |
| [SEC-07](../SEGURIDAD/issues/SEC-07-jwt-sin-revocacion-ni-clock-skew.md) — sin revocación de JWT | `CP-D38` | ❌ Se reproduce (el token sigue vivo tras el logout) |
| [SEC-08](../SEGURIDAD/issues/SEC-08-aspnet-environment-development.md) — Swagger expuesto | `CP-D40` | ❌ Se reproduce (swagger.json devuelve 200) |
| [BUG-05](../HU05/issues/BUG-05-01-filtro-presupuestos-500-postgres.md) — 500 en filtro de presupuestos | `CP-D26` | ✅ **Corregido**: 200 con el filtro `?anio&mes` |

## Afirmaciones de la documentación que la ejecución desmintió

Estas son diferencias entre lo que dice el material de presentación y lo que la API hace. Son las que más conviene
revisar antes de exponer, porque son afirmaciones comprobables por el jurado:

| Afirmación | Dónde | Veredicto |
|---|---|---|
| "`docker compose up --build` levanta los tres servicios" | Guion §5.5, §8, checklist | ❌ Falla sin el repo `frontend` clonado |
| "El contenido llega cuando es relevante, no cuando es bonito" (tip según la actividad) | Guion §3, paso 4 | ❌ No existe tip por actividad: `GET` devuelve la tabla global completa |
| "aparece la alerta" al exceder el presupuesto | Guion §8, paso 8 | ❌ Ningún soporte en la API |
| "la app calcula el progreso, lo que falta y el ritmo mensual sugerido" | Guion §3, paso 3 | ❌ La entidad no expone ninguno de los tres |
| "el token se invalida" al cerrar sesión | `DEMO_GUIDE.md` §10 | ❌ Sigue válido 8 h (`SEC-07`) |
| "tabla paginada" · "Buscar por texto" · "Filtrar por fecha desde/hasta" | `DEMO_GUIDE.md` §5, §6 | ❌ La API no pagina ni busca texto (ver [FILTROS-PAGINACION](../FILTROS-PAGINACION/README.md)) |
| "JWT con claims `idUsuario`, `idHogar`, rol y correo" | Guion §5.5 | ⚠️ El rol viaja con el URI largo de Microsoft, no como `role` (`BUG-01`) |
| "Entity Framework Core 8.0.30" | `backend/README.md` | ⚠️ El build resuelve `EF Core.Relational` 8.0.11 (ver `DEMO-11`) |
| "`dotnet test` en verde (94/94)" | Guion, checklist | ✅ Confirmado |

## Limitaciones de alcance

- **El frontend no se pudo ejecutar ni auditar**: el repo `RemesaSmartSV/frontend` no está clonado junto a este
  repositorio (ver `DEMO-01`). Por eso los 12 checks marcados como *"la API entrega X"* se reportan como
  **riesgo para la demo**, no como bug confirmado del frontend: no se puede afirmar desde aquí que el frontend
  no los compense.
- Los checks de **paginación, búsqueda por texto, exportación a CSV y filtros por fecha** que anuncia la
  `DEMO_GUIDE` no se repitieron aquí porque su ausencia en la API ya está medida y documentada en
  [`FILTROS-PAGINACION`](../FILTROS-PAGINACION/README.md).
- No se repitió la auditoría de seguridad completa ni las baterías de performance: esta entrega es la
  **recorrida del flujo de la demo**, no una re-auditoría.
