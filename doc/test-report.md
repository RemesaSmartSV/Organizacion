# Reporte de Pruebas — RemesaSmartSV

**Fecha:** 15 de septiembre de 2026  
**Proyecto:** RemesaSmartSV — Aplicación de finanzas familiares y remesas  
**Responsable:** Emelie López (documentación) / Branham Alabi (ejecución)

---

## Resumen General

| Componente | Framework | Tests | Pasaron | Fallaron | Estado |
|---|---|---|---|---|---|
| Backend (xUnit) | xUnit + EF Core InMemory | 21 | 21 | 0 | ✅ |
| Frontend (Vitest) | Vitest + React Testing Library | 2 | 2 | 0 | ✅ |
| **Total** | | **23** | **23** | **0** | **✅** |

---

## Backend — Tests Unitarios (xUnit)

### Configuración

- **Framework:** xUnit 2.5.3
- **Base de datos:** Microsoft.EntityFrameworkCore.InMemory 8.0.30
- **Autenticación:** ClaimsPrincipal mock (idUsuario=1, idHogar=1)
- **Carpeta:** `RemesSmartSV.Tests/`

### AlertasDtosTests (2 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 1 | `AlertaPeriodoRequestDTO_FechasRequeridas` | Verifica que el DTO de request de alertas por período crea instancias con fechas correctas | ✅ Pass |
| 2 | `AlertaResponseDTO_CreaInstancia` | Verifica que el DTO de response de alertas crea instancias con tipoAlerta, mensaje y porcentajeUsado | ✅ Pass |

### ReportesDtosTests (2 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 3 | `ReportePeriodoRequestDTO_FechasRequeridas` | Verifica que el DTO de request de reportes por período crea instancias con fechas correctas | ✅ Pass |
| 4 | `ReportePeriodoResponseDTO_CreaInstancia` | Verifica que el DTO de response de reportes crea instancias con totales, cantidades y balance | ✅ Pass |

### MetasAhorroControllerTests (9 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 5 | `GetMetas_RetornaListaVacia` | GET /api/MetasAhorro retorna lista paginada vacía cuando no hay metas | ✅ Pass |
| 6 | `GetMetas_RetornaSoloMetasDelHogar` | GET /api/MetasAhorro solo retorna metas del hogar autenticado (filtra por idHogar) | ✅ Pass |
| 7 | `GetMeta_RetornaMetaPorId` | GET /api/MetasAhorro/{id} retorna la meta correcta por ID | ✅ Pass |
| 8 | `GetMeta_NoExiste_RetornaNotFound` | GET /api/MetasAhorro/{id} retorna 404 cuando la meta no existe | ✅ Pass |
| 9 | `Create_AgregaMetaConValoresDefault` | POST /api/MetasAhorro crea meta con MontoActual=0 y Estado="En progreso" | ✅ Pass |
| 10 | `Update_ModificaCampos` | PUT /api/MetasAhorro/{id} actualiza título, monto objetivo y fecha límite | ✅ Pass |
| 11 | `Update_NoExiste_RetornaNotFound` | PUT /api/MetasAhorro/{id} retorna 404 cuando la meta no existe | ✅ Pass |
| 12 | `Delete_EliminaMeta` | DELETE /api/MetasAhorro/{id} elimina la meta correctamente | ✅ Pass |
| 13 | `Delete_NoExiste_RetornaNotFound` | DELETE /api/MetasAhorro/{id} retorna 404 cuando la meta no existe | ✅ Pass |

### AportesControllerTests (8 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 14 | `GetAportes_MetaNoExiste_RetornaBadRequest` | GET /api/Aportes/{metaId} retorna 400 cuando la meta no existe | ✅ Pass |
| 15 | `GetAportes_MetaExiste_RetornaLista` | GET /api/Aportes/{metaId} retorna lista de aportes de la meta | ✅ Pass |
| 16 | `Create_AgregaAporteYActualizaMeta` | POST /api/Aportes crea aporte y actualiza MontoActual de la meta | ✅ Pass |
| 17 | `Create_MontoSuperaObjetivo_MarcaComoCompletada` | POST /api/Aportes marca meta como "Completada" cuando monto supera objetivo | ✅ Pass |
| 18 | `Create_MetaNoExiste_RetornaBadRequest` | POST /api/Aportes retorna 400 cuando la meta no existe | ✅ Pass |
| 19 | `Delete_EliminaAporteYRestaMonto` | DELETE /api/Aportes/{id} elimina aporte y resta monto de la meta | ✅ Pass |
| 20 | `Delete_AporteNoExiste_RetornaNotFound` | DELETE /api/Aportes/{id} retorna 404 cuando el aporte no existe | ✅ Pass |
| 21 | `Create_SumaMontosMultiples` | POST /api/Aportes suma correctamente múltiples aportes al MontoActual | ✅ Pass |

---

## Frontend — Tests Unitarios (Vitest)

### Configuración

- **Framework:** Vitest 3.2.7
- **Librería de testing:** @testing-library/react
- **Entorno:** jsdom
- **Carpeta:** `src/`

### App.test.jsx (2 tests)

| # | Test | Descripción | Estado |
|---|---|---|---|
| 1 | `renderiza sin errores` | Verifica que el componente App renderiza sin errores de JavaScript | ✅ Pass |
| 2 | `muestra el titulo de la app` | Verifica que se muestra "RemesaSmart" en la pantalla | ✅ Pass |

---

## Endpoints Verificados (API)

| Método | Endpoint | Autenticado | Estado |
|---|---|---|---|
| POST | /api/Auth/register | No | ✅ Funcional |
| POST | /api/Auth/login | No | ✅ Funcional |
| GET | /api/Movimientos | Sí (Bearer) | ✅ Funcional |
| POST | /api/Movimientos | Sí (Bearer) | ✅ Funcional |
| GET | /api/Categorias | Sí (Bearer) | ✅ Funcional |
| POST | /api/Categorias | Sí (Bearer) | ✅ Funcional |
| GET | /api/MetasAhorro | Sí (Bearer) | ✅ Funcional |
| POST | /api/MetasAhorro | Sí (Bearer) | ✅ Funcional |
| GET | /api/Aportes/{metaId} | Sí (Bearer) | ✅ Funcional |
| POST | /api/Aportes | Sí (Bearer) | ✅ Funcional |

---

## Cobertura de Código

| Módulo | Archivos | Tests | Cobertura estimada |
|---|---|---|---|
| DTOs (Alertas, Reportes) | 2 | 4 | ~80% |
| MetasAhorroController | 1 | 9 | ~90% |
| AportesController | 1 | 8 | ~85% |
| MovimientosController | 1 | 0 (pendiente) | ~40% |
| CategoriasController | 1 | 0 (pendiente) | ~40% |
| Frontend App | 1 | 2 | ~30% |

---

## Bugs Encontrados y Corregidos

| # | Bug | Severidad | Estado |
|---|---|---|---|
| 1 | EF Core InMemory versión 8.0.11 no compatible con proyecto principal 8.0.30 | Alta | ✅ Corregido |
| 2 | Test project se compilaba dentro del proyecto principal (faltaba `<Compile Remove>`) | Alta | ✅ Corregido |
| 3 | useEffect en Layout.jsx recargaba alertas en cada cambio de ruta | Media | ✅ Corregido |
| 4 | Dropdown de alertas no se cerraba al hacer click fuera | Media | ✅ Corregido |

---

## Recomendaciones

1. **Agregar tests para MovimientosController y CategoriasController** — actualmente no tienen tests unitarios
2. **Incrementar cobertura de frontend** — solo 2 tests básicos de renderizado
3. **Agregar tests de integración** — probar flujo completo registro → login → crear movimiento
4. **Configurar code coverage** — integrar herramienta como Coverlet para métricas precisas

---

## Entorno de Ejecución

- **OS:** Windows 11
- **.NET SDK:** 10.0.302
- **Node.js:** 20.x
- **Docker:** Docker Desktop
- **Base de datos de pruebas:** EF Core InMemory (no requiere PostgreSQL)
