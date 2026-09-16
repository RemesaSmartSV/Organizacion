# Reporte de Pruebas — RemesaSmartSV

**Fecha:** 16 de septiembre de 2026
**Proyecto:** RemesaSmartSV — Aplicación de finanzas familiares y remesas
**Responsable:** Emelie López (documentación) / Branham Alabi (ejecución)

---

## Resumen General

| Componente | Framework | Tests | Pasaron | Fallaron | Estado |
|---|---|---|---|---|---|
| Backend (xUnit) | xUnit 2.9.3 + EF Core InMemory | 52 | 52 | 0 | ✅ |
| Frontend (Vitest) | Vitest + React Testing Library | — | — | — | ⏸️ Pendiente (Node no instalado) |
| **Total** | | **52** | **52** | **0** | **✅** |

> **Nota:** los tests de frontend (Vitest) no se ejecutaron en esta corrida porque
> Node.js no está instalado en el entorno. El reporte anterior registró 2 casos de
> `App.test.jsx` (renderizado y título). Quedan pendientes de re-ejecución.

---

## Backend — Tests Unitarios (xUnit)

### Configuración

- **Framework:** xUnit 2.9.3
- **Base de datos:** Microsoft.EntityFrameworkCore.InMemory 8.0.30
- **Autenticación:** ClaimsPrincipal mock (idHogar / idUsuario según cada suite)
- **Proyecto de tests (reproducible):** `backend.Tests/` (referencia a `backend/RemesaSmartSV.csproj`)
- **Comando:** `dotnet test backend.Tests\backend.Tests.csproj`
- **Resultado:** 52/52 correctos, 0 fallos, 0 omitidos (duración 8 s)

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

Los scripts E2E de API no se ejecutaron en esta corrida porque Docker Desktop no
está activo (requieren la API en `http://localhost:8080`).

| Suite | Ruta | Casos |
|---|---|---|
| HU-01 (Auth / Hogares / Usuarios) | `doc/qa/HU01/Ejecutar_Pruebas_HU01.ps1` | 27 |
| HU-05 (Presupuestos) | `doc/qa/HU05/Ejecutar_Pruebas_HU05.ps1` | 27 |
| Filtros / Paginación | `doc/qa/FILTROS-PAGINACION/Ejecutar_Pruebas_Filtros_Paginacion.ps1` | 17 |
| Performance (API) | `doc/qa/PERF/Ejecutar_Pruebas_Performance.ps1` | 8 |

---

## Cobertura de Código (estimada)

| Módulo | Suite | Tests | Cobertura estimada |
|---|---|---|---|
| AuthService | AuthServiceTests | 9 | ~85% |
| CategoriasController | CategoriasControllerTests | 12 | ~90% |
| MovimientosController | FiltrosPaginacionTests + MovimientosControllerTests | 27 | ~90% |
| PresupuestosController | FiltrosPaginacionTests | 9 | ~60% |
| Performance (read/write) | PerformanceTests | 4 | N/A (SLA) |
| Frontend App | — | pendiente | ~30% (reporte previo) |

---

## Entorno de Ejecución

- **OS:** Windows 11
- **.NET SDK:** 10.0.302
- **Runtime .NET:** 8.0.30
- **Node.js:** no instalado (frontend pendiente)
- **Docker:** Docker Desktop no activo (E2E pendiente)
- **Base de datos de pruebas:** EF Core InMemory (no requiere PostgreSQL)