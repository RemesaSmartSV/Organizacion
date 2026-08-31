# Casos de Prueba — HU-05 (Presupuestos por categoría y mes)
**Proyecto:** RemesaSmart SV — CasaTIC
**Responsable:** Emelie
**Fecha:** Jueves 27 (diseño base; endpoints confirmados del código real en `RemesaSmartSV/backend`, rama `develop`)

> Endpoints confirmados directamente del código: `PresupuestosController.cs`, `Presupuesto.cs`, `Categoria.cs`, `CategoriasController.cs` (rama `develop`, la de integración). Base URL con Docker Compose: `http://localhost:8080` (Swagger en `/swagger`). Los "esperados" marcados como **CONFIRMAR-CON-EQUIPO** dependen de los criterios de aceptación oficiales de HU-05, aún no publicados en `doc/qa`.

## 0. Notas del modelo real y precondiciones
- El **presupuesto** pertenece a `IdCategoria` + `MontoLimite` (decimal 10,2) + `MesAnio` y queda ligado al hogar del token; el `IdHogar` **se toma del token, nunca del body**.
- Para crear/editar, la **categoría debe existir y pertenecer al mismo hogar**; si no: `400` "La categoría no existe o no pertenece a tu hogar."
- El filtro de listado (`?anio=` y `?mes=`) **solo aplica si llegan ambos parámetros**; si llega solo uno, el filtro se ignora (devuelve todos).
- Se precondicionan dos hogares y sus categorías vía `register`, `Usuarios` y `Categorias` (idéntico patrón a HU-01): Hogar A (Carlos Admin, Ana Miembro, categorías Alimentación/Salario/Transporte) y Hogar B (Marta, categoría Educación).
- CONFIRMAR-CON-EQUIPO: `PresupuestosController` no restringe por rol (cualquier Miembro puede crear/editar/eliminar). `MontoLimite` y `MesAnio` no tienen validación de rango (0/negativos y mes vacío aceptados) y no hay unicidad (categoría, mes). Ver casos CP-06, CP-10, CP-11, CP-12, CP-13, CP-16, CP-17, CP-24.

## 1. Seguridad y aislamiento por hogar (`/api/Presupuestos`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-01 | Crear presupuesto sin token | POST /api/Presupuestos `{IdCategoria, MontoLimite, MesAnio}` sin Authorization | 401 Unauthorized | Alta |
| CP-02 | Listar presupuestos sin token | GET /api/Presupuestos sin Authorization | 401 Unauthorized | Alta |
| CP-03 | Crear presupuesto con token alterado | POST con token de firma modificada (último carácter) | 401 Unauthorized | Alta |
| CP-04 | Consultar presupuesto de otro hogar | GET /api/Presupuestos/{idDeHogarB} con token de Hogar A | 404 NotFound (aislamiento por `IdHogar`) | Alta |
| CP-05 | Intentar inyectar hogar ajeno en el body | POST /api/Presupuestos con `IdHogar` = idHogarB en el JSON, token de Hogar A | 201 Created y el `IdHogar` del response == idHogarA (el body no se respeta) | Alta |
| CP-06 | Operar como rol Miembro | POST/PUT/DELETE /api/Presupuestos con token de Ana (Miembro) | Comportamiento real: 201/204 (no hay restricción de rol) — **CONFIRMAR-CON-EQUIPO si solo Admin debe gestionar presupuestos** | Media |

## 2. Creación (`POST /api/Presupuestos`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-07 | Crear presupuesto válido | POST `{IdCategoria: Alimentación, MontoLimite: 300.00, MesAnio: 2026-09-01T00:00:00Z}` como Admin | 201 Created; `IdPresupuesto` asignado, `IdHogar`==claim, montos/mes correctos | Alta |
| CP-08 | Crear con categoría inexistente | POST `{IdCategoria: 99999, ...}` | 400 "La categoría no existe o no pertenece a tu hogar." | Alta |
| CP-09 | Crear con categoría de otro hogar | POST `{IdCategoria: idCatB, ...}` con token de Hogar A | 400 (mismo mensaje que CP-08) | Alta |
| CP-10 | Crear con MontoLimite = 0 | POST `{..., MontoLimite: 0}` | Comportamiento real: 201 Created (sin validación > 0) — **CONFIRMAR-CON-EQUIPO si el límite debe ser estrictamente positivo** | Media |
| CP-11 | Crear con MontoLimite negativo | POST `{..., MontoLimite: -50.00}` | Comportamiento real: 201 Created — **CONFIRMAR-CON-EQUIPO** | Media |
| CP-12 | Crear sin el campo MesAnio | POST `{IdCategoria, MontoLimite}` (sin MesAnio) | Comportamiento real: 201 Created con MesAnio default `0001-01-01T00:00:00` — **CONFIRMAR-CON-EQUIPO si el mes es obligatorio** | Media |
| CP-13 | Crear duplicado (misma categoría y mes) | Repetir el payload de CP-07 | Comportamiento real: 201 Created (sin unicidad) — **CONFIRMAR-CON-EQUIPO si debe ser único por categoría y mes** | Media |

## 3. Consulta (`GET /api/Presupuestos`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-14 | Listar todos los presupuestos del hogar | GET /api/Presupuestos (token Hogar A, con 2-3 presupuestos en distintos meses) | 200 solo presupuestos del propio hogar, ordenados por MesAnio desc | Alta |
| CP-15 | Filtrar por año y mes | GET /api/Presupuestos?anio=2026&mes=9 | 200 solo los de 2026-09 | Alta |
| CP-16 | Filtrar solo por año | GET /api/Presupuestos?anio=2026 (sin mes) | Comportamiento real: 200 con TODOS (el filtro se ignora) — **CONFIRMAR-CON-EQUIPO si debe filtrar por año solo** | Media |
| CP-17 | Filtrar solo por mes | GET /api/Presupuestos?mes=9 (sin anio) | Comportamiento real: 200 con TODOS — **CONFIRMAR-CON-EQUIPO** | Media |
| CP-18 | Filtrar sin coincidencias | GET /api/Presupuestos?anio=2027&mes=1 | 200 con lista vacía `[]` | Baja |
| CP-19 | Consultar por id propio y ajeno | GET /api/Presupuestos/{idPropio} y {idDeHogarB} | idPropio → 200; idDeHogarB → 404 | Alta |

## 4. Edición (`PUT /api/Presupuestos/{id}`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-20 | Editar MontoLimite y MesAnio (Admin) | PUT /api/Presupuestos/{id} `{MontoLimite: 250.00, MesAnio: 2026-10-01T00:00:00Z}` | 204 No Content; cambios verificados al re-consultar | Alta |
| CP-21 | Cambiar a otra categoría del mismo hogar | PUT `{IdCategoria: Transporte, ...}` | 204 No Content; `IdCategoria` actualizado | Alta |
| CP-22 | Cambiar a categoría de otro hogar | PUT `{IdCategoria: idCatB, ...}` | 400 "La categoría no existe o no pertenece a tu hogar." | Alta |
| CP-23 | Editar presupuesto de otro hogar | PUT /api/Presupuestos/{idDeHogarB} con token de Hogar A | 404 NotFound | Alta |
| CP-24 | Editar con MontoLimite 0 o negativo | PUT `{MontoLimite: 0}` y luego `-10` | Comportamiento real: 204 No Content — **CONFIRMAR-CON-EQUIPO** | Media |

## 5. Eliminación (`DELETE /api/Presupuestos/{id}`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-25 | Eliminar presupuesto propio | DELETE /api/Presupuestos/{idPropio} | 204 No Content; 404 al re-consultar | Media |
| CP-26 | Eliminar presupuesto de otro hogar | DELETE /api/Presupuestos/{idDeHogarB} con token de Hogar A | 404 NotFound | Media |
| CP-27 | Eliminar presupuesto inexistente | DELETE /api/Presupuestos/99999 | 404 NotFound | Media |

## Resumen
- Total de casos: 27
- Cobertura: seguridad (token ausente/alterado), aislamiento por hogar (id del token vs body), creación (válida, categoría inexistente/ajena, límites y mes), consulta (listado, filtros anio/mes, por id), edición (monto, mes, cambio de categoría), eliminación, y control de acceso por rol.
- **Hallazgos a validar con el equipo antes de ejecutar:** (1) los presupuestos no restringen por rol (CP-06); (2) `MontoLimite` acepta 0 y negativos (CP-10/CP-11/CP-24); (3) `MesAnio` sin mes se guarda como `0001-01-01` (CP-12); (4) se permiten duplicados categoría+mes (CP-13); (5) el filtro exige anio y mes juntos (CP-16/CP-17). Dependiendo de los criterios de aceptación de HU-05, estos casos pueden convertirse en bugs.
- **Bloqueante preexistente a verificar en el integrado:** BUG-01 (JWT sin claim corto `role`) no bloquea las pruebas de API, pero sí la lógica de rol en el frontend.