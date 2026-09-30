# Reporte de Pruebas — RemesaSmartSV

**Fecha:** 27 de septiembre de 2026 (última corrida: demo end-to-end + auditoría de seguridad — issue #76)
**Proyecto:** RemesaSmartSV — Aplicación de finanzas familiares y remesas
**Responsable:** Emelie López (documentación) / Branham Alabi (ejecución QA)

> 📌 **Para la próxima iteración:** los 27 issues abiertos que dejan estas corridas, sus dependencias, las
> 14 decisiones de comportamiento pendientes del equipo y la deuda de proceso que no tiene issue, están
> consolidados y priorizados en [`doc/qa/BACKLOG-MVP3.md`](qa/BACKLOG-MVP3.md).

---

## Resumen General

| Componente | Framework | Tests | Pasaron | Fallaron | Estado |
|---|---|---|---|---|---|
| Backend (xUnit) | xUnit 2.9.3 + EF Core InMemory | 94 | 94 | 0 | ✅ |
| └ Funcional QA previa | xUnit 2.9.3 | 52 | 52 | 0 | ✅ |
| └ **Seguridad (issue #76)** | xUnit 2.9.3 + `JwtSecurityTokenHandler` + reflexión | **42** | **42** | **0** | ⚠️ **10 hallazgos (2 críticos)** |
| HU-01 (Auth/Hogares/Usuarios · API) | PowerShell + HTTP (Docker) | 27 | 25 | 2 | ⚠️ 2 bugs abiertos (BUG-01, BUG-02) |
| HU-05 (Presupuestos · API) | PowerShell + HTTP (Docker) | 27 | 27 | 0 | ✅ |
| Filtros/Paginación (API) | PowerShell + HTTP (Docker) | 17 | 17 | 0 | ✅ |
| Performance (API) | PowerShell + HTTP (Docker) | 8 | 7 | 0 | ✅ (1 SALTADO opcional) |
| **Demo end-to-end (API)** | PowerShell + HTTP (Docker) | **40** | **28** | **12** | ⚠️ **11 hallazgos (3 bloqueantes)** |
| Frontend (Vitest) | Vitest + React Testing Library | — | — | — | ⏸️ Pendiente (Node no instalado) |
| **Total** | | **213** | **198** | **14** | **⚠️** |

> **Nota:** los tests de frontend (Vitest) no se ejecutaron porque Node.js no está
> instalado en el entorno (reporte previo: 2 casos de `App.test.jsx` pendientes).
>
> La demo end-to-end recorre los 10 pasos del guion de presentación contra la API
> real. **6 de sus 12 fallos no son bugs del backend**: son datos que la API no
> entrega y que el frontend calcula en el cliente (barra de presupuesto, alerta de
> exceso, marca de remesa, ritmo de meta, tip contextual, cierre de sesión). Como el
> repo `frontend/` no está clonado, no se pudo verificar cuáles implementa. Detalle y
> evidencia en `doc/qa/DEMO-E2E/README.md`.
>
> **Bug corregido durante esta corrida:** `GET /api/Presupuestos?anio=&mes=` devolvía
> `500` con PostgreSQL cuando existía un presupuesto con `MesAnio` por defecto
> (`0001-01-01` → `-infinity`). Corregido en `PresupuestosController` mediante
> filtro por rango de fechas (UTC). Ver `doc/qa/HU05/issues/BUG-05-01-filtro-presupuestos-500-postgres.md`.
> Sin regresión: xUnit sigue **52/52**.

---

## Backend — Tests Unitarios (xUnit)

### Configuración

- **Framework:** xUnit 2.9.3
- **Base de datos:** Microsoft.EntityFrameworkCore.InMemory 8.0.30
- **Autenticación:** ClaimsPrincipal mock (idHogar / idUsuario según cada suite) + validación real de JWT con `JwtSecurityTokenHandler`
- **Proyecto de tests (reproducible):** `backend.Tests/` (referencia a `backend/RemesaSmartSV.csproj`)
- **Comando:** `dotnet test backend.Tests\backend.Tests.csproj`
- **Resultado:** 94/94 correctos, 0 fallos, 0 omitidos (duración ~9 s) — 52 de la suite funcional previa + 42 de seguridad
- **Entrega de seguridad:** `doc/qa/SEGURIDAD/` (informe, 42 casos, 10 issues, CSV/JSON, log)

### AuthServiceTests (9 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 1 | `RegisterAsync_ConNuevoCorreo_RegistraHogarYUsuarioAdmin` | Registro crea hogar y usuario admin | ✅ Pass |
| 2 | `RegisterAsync_ConCorreoDuplicado_SinDiferenciarMayusculas_DevuelveNull` | Correo duplicado (case-insensitive) retorna null | ✅ Pass |
| 3 | `RegisterAsync_ConCorreoDuplicado_NoCreaHogarNiUsuario` | No persiste hogar/usuario duplicado | ✅ Pass |
| 4 | `RegisterAsync_DevuelveTokenJwtValidoConClaims` | Emite JWT con claims esperados | ✅ Pass |
| 5 | `LoginAsync_ConCredencialesCorrectas_DevuelveToken` | Login correcto devuelve token | ✅ Pass |
| 6 | `LoginAsync_ConCorreoInexistente_DevuelveNull` | Login con correo inexistente devuelve null | ✅ Pass |
| 7 | `LoginAsync_ConCorreoEnMinusculasYRegistroEnMayusculas_Autentica` | Login normaliza mayúsculas | ✅ Pass |
| 8 | `LoginAsync_ConContrasenaIncorrecta_DevuelveNull` | Contraseña incorrecta rechaza | ✅ Pass |
| 9 | `RegisterAsync_AsignaContrasenaHasheadaNoPlana` | La contraseña no se almacena en plano | ✅ Pass |

### CategoriasControllerTests (12 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 10 | `GetCategorias_SoloDevuelveCategoriasDelHogarOrdenadasPorNombre` | GET /api/Categorias filtra por hogar y ordena | ✅ Pass |
| 11 | `GetCategoria_DeMismoHogar_DevuelveCategoria` | GET /{id} del mismo hogar devuelve la categoría | ✅ Pass |
| 12 | `GetCategoria_DeOtroHogar_DevuelveNotFound` | GET /{id} de otro hogar devuelve 404 | ✅ Pass |
| 13 | `GetCategoria_Inexistente_DevuelveNotFound` | GET /{id} inexistente devuelve 404 | ✅ Pass |
| 14 | `Create_AsignaHogarDelUsuarioYPersiste` | POST asigna idHogar del claim | ✅ Pass |
| 15 | `Create_IgnoraIdCategoriaProporcionado` | POST ignora el IdCategoria enviado | ✅ Pass |
| 16 | `Update_DeMismoHogar_ActualizaCamposYDevuelveNoContent` | PUT actualiza campos y retorna 204 | ✅ Pass |
| 17 | `Update_DeOtroHogar_NoModificaYDevuelveNotFound` | PUT de otro hogar no modifica (404) | ✅ Pass |
| 18 | `Update_Inexistente_DevuelveNotFound` | PUT inexistente devuelve 404 | ✅ Pass |
| 19 | `Delete_DeMismoHogar_EliminaYDevuelveNoContent` | DELETE del mismo hogar elimina (204) | ✅ Pass |
| 20 | `Delete_DeOtroHogar_NoEliminaYDevuelveNotFound` | DELETE de otro hogar no elimina (404) | ✅ Pass |
| 21 | `Delete_Inexistente_DevuelveNotFound` | DELETE inexistente devuelve 404 | ✅ Pass |

### FiltrosPaginacionTests (9 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 22 | `GetMovimientos_FiltroCombinadoCategoriaYTipo_DevuelveSoloLaInterseccion` | Filtro combinado (categoría+tipo) retorna intersección | ✅ Pass |
| 23 | `GetMovimientos_FiltroCategoriaInexistente_DevuelveVacio` | Categoría inexistente devuelve vacío | ✅ Pass |
| 24 | `GetMovimientos_FiltroTipoConEspacios_SeIgnoraYDevuelveTodos` | Filtro tipo con espacios se ignora | ✅ Pass |
| 25 | `GetMovimientos_CienRegistros_SinPaginacionDevuelveTodos` | 100 registros sin paginación devuelve todos | ✅ Pass |
| 26 | `GetPresupuestos_FiltroAnioYMes_DevuelveSoloElMesSolicitado` | Presupuestos filtra año+mes | ✅ Pass |
| 27 | `GetPresupuestos_FiltroSoloAnio_SinMesSeIgnoraYDevuelveTodos` | Solo año sin mes se ignora | ✅ Pass |
| 28 | `GetPresupuestos_FiltroSoloMes_SinAnioSeIgnoraYDevuelveTodos` | Solo mes sin año se ignora | ✅ Pass |
| 29 | `GetPresupuestos_FiltroSinCoincidencias_DevuelveVacio` | Sin coincidencias devuelve vacío | ✅ Pass |
| 30 | `GetPresupuestos_CincuentaRegistros_SinPaginacionDevuelveTodos` | 50 registros sin paginación devuelve todos | ✅ Pass |

### MovimientosControllerTests (18 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 31 | `GetMovimientos_SinFiltros_DevuelveDelHogarOrdenadosPorFechaDescendente` | GET sin filtros filtra hogar y ordena por fecha desc | ✅ Pass |
| 32 | `GetMovimientos_ConFiltroCategoriaId_SoloDevuelveDeEsaCategoria` | Filtro por categoría | ✅ Pass |
| 33 | `GetMovimientos_ConFiltroTipo_SoloDevuelveDeEseTipo` | Filtro por tipo | ✅ Pass |
| 34 | `GetMovimientos_ConFiltroTipoEnMinusculas_DevuelveVacio` | Filtro tipo en minúsculas devuelve vacío | ✅ Pass |
| 35 | `GetMovimiento_DeMismoHogar_DevuelveMovimiento` | GET /{id} del mismo hogar | ✅ Pass |
| 36 | `GetMovimiento_DeOtroHogar_DevuelveNotFound` | GET /{id} de otro hogar (404) | ✅ Pass |
| 37 | `GetMovimiento_Inexistente_DevuelveNotFound` | GET /{id} inexistente (404) | ✅ Pass |
| 38 | `Create_ConCategoriaDelHogar_AsignaHogarYUsuarioYPersiste` | POST asigna hogar/usuario y persiste | ✅ Pass |
| 39 | `Create_ConCategoriaDeOtroHogar_DevuelveBadRequestYNoPersiste` | POST con categoría de otro hogar (400, no persiste) | ✅ Pass |
| 40 | `Create_ConCategoriaInexistente_DevuelveBadRequestYNoPersiste` | POST con categoría inexistente (400) | ✅ Pass |
| 41 | `Update_DeMismoHogar_ActualizaCamposYDevuelveNoContent` | PUT actualiza y retorna 204 | ✅ Pass |
| 42 | `Update_CambioACategoriaValidaDelHogar_ActualizaIdCategoria` | PUT cambia a categoría válida del hogar | ✅ Pass |
| 43 | `Update_CambioACategoriaDeOtroHogar_DevuelveBadRequestYNoCambia` | PUT cambia a categoría de otro hogar (400) | ✅ Pass |
| 44 | `Update_DeOtroHogar_DevuelveNotFound` | PUT de otro hogar (404) | ✅ Pass |
| 45 | `Update_Inexistente_DevuelveNotFound` | PUT inexistente (404) | ✅ Pass |
| 46 | `Delete_DeMismoHogar_EliminaYDevuelveNoContent` | DELETE elimina (204) | ✅ Pass |
| 47 | `Delete_DeOtroHogar_NoEliminaYDevuelveNotFound` | DELETE de otro hogar no elimina (404) | ✅ Pass |
| 48 | `Delete_Inexistente_DevuelveNotFound` | DELETE inexistente (404) | ✅ Pass |

### PerformanceTests (4 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 49 | `GetMovimientos_ConDosMilRegistros_RespondeEnMenosDeCincoSegundos` | 2000 registros en < 5 s | ✅ Pass |
| 50 | `GetMovimientos_ConFiltroYDiezMilRegistros_RespondeEnMenosDeCincoSegundos` | Filtro sobre 10000 registros en < 5 s | ✅ Pass |
| 51 | `Create_MilMovimientosSecuenciales_TardaMenosDeDiezSegundos` | 1000 creates secuenciales en < 10 s | ✅ Pass |
| 52 | `GetPresupuestos_ConDosMilRegistros_RespondeEnMenosDeCincoSegundos` | 2000 presupuestos filtrados en < 5 s | ✅ Pass |

### SeguridadTests (42 tests — issue #76)

Detalle completo en `doc/qa/SEGURIDAD/Casos_Prueba_Seguridad.md` (CP-S-01..CP-S-42, agrupados por área temática).
Esta tabla agrupa por **clase de test**; el documento de casos agrupa temáticamente (12 en CSRF/Autorización y 10 en Cabeceras, porque tres tests de configuración —CORS, orden del pipeline, bearer sin cookies— son de CSRF/autorización). Los 42 son los mismos.
Convención: los tests con prefijo `Vuln_SECxx_` **afirman que la vulnerabilidad sigue presente** y
pasarán a rojo cuando se corrija el hallazgo; el resto son controles que deben seguir en verde.

| # | Suite | Tests | Qué cubre | Resultado |
|---|-------|-------|-----------|-----------|
| 53-62 | `SeguridadJwtTests` | 10 | Validación de firma/`iss`/`aud`/vigencia, rechazo de token falsificado, vida de 8 h, `jti` ausente (**SEC-07**), `ClockSkew` de 5 min (**SEC-07**) | 10/10 ✅ |
| 63-67 | `SeguridadContrasenasTests` | 5 | PBKDF2 + sal, hash por usuario, rechazo de clave incorrecta, `ContrasenaHash` nunca serializado | 5/5 ✅ |
| 68-76 | `SeguridadAutorizacionTests` | 9 | Sin cookies/antiforgery (**CSRF**), CORS sin wildcard ni credenciales, orden del pipeline, superficie anónima (4 endpoints), `Roles="Admin"` en operaciones críticas, `IdHogar` del token (anti-IDOR), `Rol` sin lista blanca (**SEC-06**) | 9/9 ✅ |
| 77-81 | `SeguridadXssTests` | 5 | Payload `<script>` persistido sin sanear (**SEC-05**), escape JSON (`\u003C`), tips como datos y no HTML, límites de longitud, `Contenido` sin cota (**SEC-05**) | 5/5 ✅ |
| 82-94 | `SeguridadConfiguracionTests` | 13 | `Validate*` del JWT activos, sin SQL crudo, **clave JWT versionada (SEC-01)**, **contraseña BD versionada (SEC-02)**, **sin cabeceras (SEC-03)**, **sin rate limit (SEC-04)**, compose en `Development` (**SEC-08**), sin TLS (**SEC-09**), CI sin escaneo de secretos ni tests (**SEC-10**) | 13/13 ✅ |

**Hallazgos de seguridad:** 2 críticos (SEC-01, SEC-02) · 2 altos (SEC-03, SEC-04) · 5 medios (SEC-05..SEC-09) · 1 baja (SEC-10) — issues en `doc/qa/SEGURIDAD/issues/`.

---

## Frontend — Tests Unitarios (Vitest)

### Configuración

- **Framework:** Vitest 3.2.7
- **Librería de testing:** @testing-library/react
- **Entorno:** jsdom
- **Carpeta:** `src/` (repositorio `RemesaSmartSV/frontend`)
- **Comando:** `npm run test` (vitest run)

### Estado: ⏸️ Pendiente

No se ejecutó en esta corrida porque Node.js no está instalado en el entorno.
La suite registrada anteriormente incluye 2 casos en `App.test.jsx`:

| # | Test | Descripción | Estado |
|---|---|---|---|
| 1 | `renderiza sin errores` | Verifica que App renderiza sin errores | ⏸️ No ejecutado |
| 2 | `muestra el titulo de la app` | Verifica que se muestra "RemesaSmart" | ⏸️ No ejecutado |

---

## Pruebas de Integración (scripts PowerShell + Docker)

Ejecutadas el **23/09/2026** contra el entorno integrado (`docker compose up` con
PostgreSQL 16 + API .NET 8 en `http://localhost:8080`) y base limpia
(`docker compose down -v` antes de cada batería).

| Suite | Ruta | Casos | Resultado |
|---|---|---|---|
| HU-01 (Auth / Hogares / Usuarios) | `doc/qa/HU01/Ejecutar_Pruebas_HU01.ps1` | 27 | 25 PASS / 2 FAIL (corrida previa) |
| HU-05 (Presupuestos) | `doc/qa/HU05/Ejecutar_Pruebas_HU05.ps1` | 27 | **27/27 PASS** |
| Filtros / Paginación | `doc/qa/FILTROS-PAGINACION/Ejecutar_Pruebas_Filtros_Paginacion.ps1` | 17 | **17/17 PASS** |
| Performance (API) | `doc/qa/PERF/Ejecutar_Pruebas_Performance.ps1` | 8 | **7/7 PASS** + 1 SALTADO |
| **Demo end-to-end** | `doc/qa/DEMO-E2E/Ejecutar_Demo_E2E.ps1` | **40** | **28 PASS / 12 FAIL** |
| **Total** | | **119** | **104 PASS · 14 FAIL · 1 SALTADO** |

### Demo end-to-end — 28/40 PASS (corrida del 27/09/2026)

Recorre los 10 pasos del guion de presentación más el cierre de sesión, contra la
API real en Docker y sobre volumen limpio (`docker compose down -v` antes). Es la
primera vez que la batería se ejecuta sobre base limpia: en el volumen anterior había
datos de QA previos (1 hogar, 1 usuario, 50 categorías, 1005 movimientos, 201
presupuestos), que se descartaron.

| Paso del guion | Checks | Resultado |
|---|---|---|
| 1. Despliegue | 1/2 | ⚠️ `docker compose up --build` falla (falta `../frontend`) |
| 2. Registro (hogar + Admin) | 4/4 | ✅ |
| 2b. Login / sesión | 2/4 | ⚠️ claim `role` con URI larga, sin `iat` |
| 3. Agregar miembro | 3/3 | ✅ |
| 4. Remesa de $400 | 4/4 | ✅ `origenEmisora` con UTF-8 correcto |
| 5. Gasto de $120 | 2/2 | ✅ |
| 6. Tablero | 2/3 | ⚠️ no hay endpoint de tablero |
| 7. Presupuesto $300 → 40 % | 3/4 | ✅ el 40 % es exacto; la API no devuelve el consumo |
| 8. Gasto $200 más → alerta | 2/3 | ⚠️ **momento clave**: la alerta no existe en la API |
| 9. Meta $2.000 a 6 meses | 5/6 | ✅ aporte y estado automático; falta el ritmo mensual |
| 10. Educación Financiera | 0/2 | ❌ la sección sale vacía |
| 11. Cierre de sesión | 0/3 | ❌ el token sigue válido tras el logout |

**Regresión verde confirmada en esta corrida:** `BUG-05` — el filtro de presupuestos
por `anio`/`mes` responde 200 contra PostgreSQL real, sin el 500 que veía en la
corrida previa.

**Hallazgos previos reproducidos:** `BUG-01`, `SEC-03`, `SEC-07`, `SEC-08`.

**Fallo de arranque en base limpia:** en la primera ejecución tras `down -v` la API
se cae con `NpgsqlException: Failed to connect to 172.18.0.2:5432` y revive por
`restart: on-failure`; el segundo intento aplica `20260811193629_InitialCreate`. Causa:
`Migrate()` sin reintento y `depends_on` sin healthcheck. Ver `DEMO-03`.

### HU-05 — Presupuestos (27/27 PASS)

Cobertura: seguridad/aislamiento (sin token, token alterado, hogar ajeno, inyección
de `idHogar`), creación (categoría inexistente/ajena, `MontoLimite=0/negativo`),
consulta (filtros `anio+mes`, aislamiento, orden desc), edición (categoría ajena,
404), eliminación (propio/ajeno/inexistente).

> ⚠️ Casos marcados **CONFIRMAR-CON-EQUIPO** (comportamiento real, no fallo): rol
> Miembro puede operar presupuestos (CP-06), `MontoLimite` admite 0/negativo
> (CP-10/11/24), `MesAnio` no es obligatorio (CP-12) y no hay unicidad
> categoría+mes (CP-13). Si la especificación exige lo contrario, son bugs de
> validación a reportar. Detalle en `doc/qa/HU05/Casos_Prueba_HU05.md`.

### Filtros / Paginación (17/17 PASS)

- **Filtros de Movimientos:** por categoría, tipo, combinado e inexistente, con
  aislamiento por hogar y orden por fecha desc. Confirmado: `?tipo=gasto`
  (minúsculas) devuelve vacío (comparación sensible a mayúsculas, FP-05).
- **Filtros de Presupuestos:** `anio+mes` → solo ese mes; solo `anio` o solo `mes`
  → devuelve todo (filtro ignorado); sin coincidencias → `[]`.
- **Paginación:** no existe en el backend; `page`/`pageSize` se ignoran y los
  listados devuelven el set completo (FP-13 a FP-17). **CONFIRMAR-CON-EQUIPO** si
  debe implementarse para el MVP.

### Performance (API) — línea base con PostgreSQL

Ejecutado con volúmenes por defecto (1.000 movimientos, 200 presupuestos, 50
categorías, 5 repeticiones). **PP-05 (volumen alto)** quedó `SALTADO` por diseño:
requiere `-Movimientos 10000`.

| Caso | Escenario | Mediana | p95 | Umbral | Estado |
|---|---|---|---|---|---|
| PP-01 | GET Movimientos (1.000) | 17 ms | 19 ms | 500 | ✅ |
| PP-02 | GET Movimientos filtro cat+tipo | 12 ms | 13 ms | 500 | ✅ |
| PP-03 | GET Presupuestos `anio+mes` | 9 ms | 9 ms | 500 | ✅ |
| PP-04 | GET Categorías (50) | 20 ms | 28 ms | 300 | ✅ |
| PP-06 | POST Movimiento puntual | 13 ms | 13 ms | 500 | ✅ |
| PP-07 | Siembra masiva 1.000 (secuencial) | 16.6 s global | — | 90.000 | ✅ |
| PP-08 | Login | 110 ms | 115 ms | 500 | ✅ |

> Para correr PP-05 (volumen alto): `-Movimientos 10000` (siembra ~2.5 min).

---

## Cobertura de Código (estimada)

| Módulo | Suite | Tests | Cobertura estimada |
|---|---|---|---|
| AuthService | AuthServiceTests + SeguridadJwtTests | 19 | ~85% |
| CategoriasController | CategoriasControllerTests | 12 | ~90% |
| MovimientosController | FiltrosPaginacionTests + MovimientosControllerTests | 27 | ~90% |
| PresupuestosController | FiltrosPaginacionTests | 9 | ~60% |
| Usuarios / Hogares / Tips | SeguridadAutorizacionTests (atributos y mass assignment) | 9 | atributos verificados |
| Configuración / pipeline | SeguridadConfiguracionTests (archivos versionados) | 13 | 100% del arranque |
| Performance (read/write) | PerformanceTests | 4 | N/A (SLA) |
| Frontend App | — | pendiente | ~30% (reporte previo) |

---

## Entorno de Ejecución

- **OS:** Windows 11 · PowerShell 5.1
- **.NET SDK:** 10.0.302
- **Runtime .NET:** 8.0.30
- **Node.js:** no instalado (frontend pendiente)
- **Docker:** Docker Desktop **no activo** el 27/09/2026 → la corrida de seguridad fue estática + xUnit (sin API en vivo). Docker Desktop sí estuvo activo en la corrida del 23/09/2026 (PostgreSQL 16 + API en `http://localhost:8080`)
- **Bases de datos de pruebas:** EF Core InMemory (xUnit) + PostgreSQL 16 (suites de integración API)
- **Código auditado:** snapshot del backend en rama `develop` (`backend-develop.zip`) extraído en `backend/`

## Hallazgos y acciones de esta corrida

| # | Hallazgo | Tipo | Acción |
|---|---|---|---|
| SEC-01 | `Jwt:Key` hardcodeada y versionada en `appsettings.json` → se pueden firmar tokens `Admin` de cualquier hogar | Seguridad (**crítica**) | Reportado, sin corregir. Rotar la clave e inyectarla por entorno. `doc/qa/SEGURIDAD/issues/SEC-01-...md` |
| SEC-02 | Contraseña de PostgreSQL en texto plano en `docker-compose.yml`, reutilizada por la API, con `5432:5432` publicado | Seguridad (**crítica**) | Reportado, sin corregir. Mover a `.env` no versionado y rotar. `doc/qa/SEGURIDAD/issues/SEC-02-...md` |
| SEC-03 | Cero cabeceras de seguridad (sin `nosniff`, CSP, `X-Frame-Options`, `Referrer-Policy`, HSTS) | Seguridad (alta) | Reportado. Middleware de cabeceras en `Program.cs`. `SEC-03-...md` |
| SEC-04 | Sin rate limiting ni bloqueo de cuenta en `/api/Auth/login` y `/register` (contraseñas de 6 caracteres) | Seguridad (alta) | Reportado. `AddRateLimiter` + bloqueo por intentos fallidos. `SEC-04-...md` |
| SEC-05 | Texto libre persistido sin sanear (riesgo de XSS almacenado en el frontend) y `EducacionFinanciera.Contenido` sin límite de longitud | Seguridad (media) | Reportado. Coordinar con frontend: nunca `dangerouslySetInnerHTML` + CSP. `SEC-05-...md` |
| SEC-06 | `Rol` es texto libre sin lista blanca (`SuperAdmin`, `admin`…) | Seguridad (media) | Reportado. Enum/mapa de dominio (mismo patrón que BUG-03). `SEC-06-...md` |
| SEC-07 | JWT sin `jti`/revocación/refresh y `ClockSkew` de 5 min por defecto → cambios de rol no surten efecto hasta 8 h | Seguridad (media) | Reportado. `jti` + denylist y vida corta + refresh. `SEC-07-...md` |
| SEC-08 | Compose con `ASPNETCORE_ENVIRONMENT=Development` → Swagger UI y stack traces expuestos | Seguridad (media) | Reportado. Default `Production` + flag explícito para Swagger. `SEC-08-...md` |
| SEC-09 | API en `http://+:8080` y BD en `5432:5432` sin TLS, con `UseHttpsRedirection()` inoperante | Seguridad (media) | Documentado. TLS en el proxy/ingress; puertos atados a loopback en local. `SEC-09-...md` |
| SEC-10 | CI sin escaneo de secretos ni `dotnet test`, `AllowedHosts: "*"`, validación de modelo desactivada | Seguridad (baja) | Reportado. Gitleaks + `dotnet test` en el workflow. `SEC-10-...md` |
| BUG-05-01 | `GET /api/Presupuestos?anio=&mes=` → 500 `integer out of range` en PostgreSQL si existe un `MesAnio=0001-01-01` (`-infinity`) | Bug (solo PostgreSQL) | **Corregido** en `Controllers/PresupuestosController.cs` (filtro por rango UTC). Issue: `doc/qa/HU05/issues/BUG-05-01-...md` |
| PS (scripts QA) | `@($body \| ConvertFrom-Json)` anida el array un nivel en PowerShell 5.1 | Bug de script | Corregido en los 3 scripts (HU-05, FP, PERF): re-emisión con `ForEach-Object { $_ }` |
| PS (script PERF) | `$body = $r.Body` pisaba el parámetro `$Body` (case-insensitive) → lanzaba ProtocolViolation en GET | Bug de script | Corregido: variable local renombrada a `$respBody` |
| PS (script seguridad) | `Tee-Object` en PowerShell 5.1 escribe el log en UTF-16 (git lo trataba como binario) y la salida de `dotnet` llegaba con las rutas absolutas del equipo | Bug de script | `Generar_Resultados_Seguridad.ps1` redirige la consola a archivo, la relee como UTF-8, sustituye `<repo>`/`<user>` y filtra el ruido de MSB3277; genera CSV/JSON |
| CONFIRMAR-CON-EQUIPO | HU-01: BUG-01 (claim `role` corto en JWT) y BUG-02 (`PUT /api/Hogares` sin restricción Admin) | Bugs abiertos | Pendientes de decisión del equipo (`doc/qa/HU01/issues/`); BUG-01 solapa con SEC-07 |
| CONFIRMAR-CON-EQUIPO | HU-05: permisos de Miembro, `MontoLimite<=0`, `MesAnio` opcional, unicidad categoría+mes | Comportamiento real | Revisar criterios de aceptación (CP-06, CP-10..13, CP-24) |
| CONFIRMAR-CON-EQUIPO | Backend sin paginación en ningún listado | Faltante documentado | Definir si es defecto o *works as designed* para el MVP |
| NO VERIFICADO | Frontend (render de texto, CSP, almacenamiento del token) y API en vivo (cabeceras reales, cuerpo de error 500, rate limit) | Alcance | Requiere repo `frontend` con Node y Docker Desktop activo; pasos concretos en `doc/qa/SEGURIDAD/issues/` |
| DEMO-01 | `docker compose up --build` aborta: el servicio `frontend_web` no encuentra el contexto `../frontend`, que no está clonado. Es el paso 1 del guion | Bug (despliegue) | **Bloqueante.** Reportado. Levantar `postgres_db backend_api` y el frontend por separado, o versionar el compose del backend aparte. `doc/qa/DEMO-E2E/issues/DEMO-01-...md` |
| DEMO-02 | Educación Financiera sin contenido: `GET /api/TipsFinancieros` devuelve 0 filas, la migración `InitialCreate` no siembra tips | Bug (contenido) | **Bloqueante.** Reportado. Sembrar en una migración, ver `DEMO-10` para el modelo. `doc/qa/DEMO-E2E/issues/DEMO-02-...md` |
| DEMO-03 | En el primer arranque sobre base limpia la API se cae: `Migrate()` corre sin esperar a PostgreSQL, sin reintento, y `depends_on` no tiene healthcheck | Bug (fiabilidad) | Reportado. Healthcheck en `postgres_db` + `depends_on: condition: service_healthy`, y reintento con espera exponencial sobre `Migrate()`. `doc/qa/DEMO-E2E/issues/DEMO-03-...md` |
| DEMO-04 | La API no entrega alerta de presupuesto excedido: sin campo, sin endpoint y sin código HTTP. El guion lo marca como el momento clave de la demo | Falta de contrato | **Bloqueante del momento clave.** Reportado. Agregar el consumo y la alerta al modelo de `Presupuesto` (ver `DEMO-06`). `doc/qa/DEMO-E2E/issues/DEMO-04-...md` |
| DEMO-05 | `Movimiento.Tipo` es texto libre sin lista blanca: una remesa se puede guardar como `Gasto` (mismo patrón que `BUG-03` y `SEC-06`) | Bug (validación) | Reportado. Lista blanca en el modelo + validación en el controlador. `doc/qa/DEMO-E2E/issues/DEMO-05-...md` |
| DEMO-06 | `Presupuesto` no expone `montoGastado` ni porcentaje: la barra se calcula en el cliente | Falta de contrato | Reportado. Derivar ambos en el modelo, como ya hace `MetaAhorro` con `montoActual`. `doc/qa/DEMO-E2E/issues/DEMO-06-...md` |
| DEMO-07 | No hay endpoint de tablero o resumen: los números de flujo, distribución y saldo los deriva el cliente | Falta de contrato | Reportado. Definir si es alcanzable del MVP o *works as designed*. `doc/qa/DEMO-E2E/issues/DEMO-07-...md` |
| DEMO-08 | La remesa se distingue solo por convención de `origenEmisora`: no hay marca explícita, y distinguirla del gasto depende del texto | Falta de contrato | Reportado. Marcar el tipo de movimiento en la API. `doc/qa/DEMO-E2E/issues/DEMO-08-...md` |
| DEMO-09 | `MetaAhorro` no expone faltante ni ritmo mensual sugerido, que son los que promete el guion | Falta de contrato | Reportado. Mismo criterio que `DEMO-06`. `doc/qa/DEMO-E2E/issues/DEMO-09-...md` |
| DEMO-10 | `EducacionFinanciera` es contenido global pero su FK `IdCategoria` apunta a `Categorias`, que es por hogar: no hay forma de sembrar un tip sin crear una categoría de una familia, y `PUT` no valida el hogar, así que un Admin de una familia edita el contenido global | Bug (modelo/autorización) | Reportado. Desacoplar con `Tema`/`Icono` de texto libre y bajar el permiso a un rol de contenido. `doc/qa/DEMO-E2E/issues/DEMO-10-...md` |
| DEMO-11 | El build resuelve `EF Core.Relational` 8.0.11 contra los 8.0.30 declarados (MSB3277) y no hay `global.json`, así que `dotnet test` compiló con el SDK 10.0.302 y no con el 8 documentado | Higiene de build | Reportado. Alinear Npgsql y agregar `global.json`. Riesgo: los tests con InMemory pueden no reflejar el comportamiento con Npgsql real. `doc/qa/DEMO-E2E/issues/DEMO-11-...md` |