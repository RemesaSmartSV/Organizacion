# Backlog de MVP 3 — Issues conocidos y mejoras pendientes

**Responsable:** Emelie · **Rol:** QA
**Alcance:** consolidación de **todo** lo que las siete entregas de QA dejaron abierto, más lo que quedó
sin issue por ser deuda de proceso. **No es una entrega nueva**: no agrega pruebas ni evidencia, las
reordena y las prioriza para la próxima iteración.
**Componente:** `backend/` (ASP.NET Core Web API .NET 8) + `frontend/` (repo hermano, no versionado aquí)
**Fecha de corte:** domingo 27 de septiembre de 2026
**Fuentes:** [SEGURIDAD](SEGURIDAD/README.md) · [DEMO-E2E](DEMO-E2E/README.md) ·
[backend-tests](backend-tests/issues/) · [HU01](HU01/README.md) · [HU05](HU05/Casos_Prueba_HU05.md) ·
[FILTROS-PAGINACION](FILTROS-PAGINACION/README.md) · [PERF](PERF/README.md) ·
[reporte de pruebas](../test-report.md)
**Método:** consolidation documental de 28 archivos de issue y 213 casos de prueba ya ejecutados
(`dotnet test` 94/94 · API real 119 casos). **Ningún hallazgo se _(re)descubrió_ para este documento.**

---

## Resultado en una línea

> **28 issues documentados → 27 abiertos y 1 corregido · 2 críticos de seguridad · 3 bloqueantes de la demo
> · 14 preguntas de comportamiento sin respuesta del equipo · 5 deudas de proceso que, si no se cierran,
> dejan volver a entrar el mismo tipo de bug sin que nadie lo note**

| | Detalle |
|---|---|
| Issues abiertos consolidados | **27** (de 28 documentados) |
| 🔴 Críticos | 2 (`SEC-01`, `SEC-02`) |
| 🔴/🟠 Altos | 8 |
| 🟡 Medios | 15 |
| 🟢 Bajos | 2 |
| Issues ya corregidos | 1 (`BUG-05-01`, regresión verde confirmada contra PostgreSQL real) |
| Decisiones pendientes del equipo | **14** casos `CONFIRMAR-CON-EQUIPO` + 7 decisiones de diseño (§5.3) |
| Deuda de proceso sin issue | 5 secciones (ver §6) |
| Tests en verde hoy | 94/94 xUnit · 198/213 contando las suites de API |

**Advertencia de lectura:** este backlog **no agrega hallazgos**. Si algo no está aquí, es porque las
baterías no lo midieron — no porque esté bien. La sección §6 lista explícitamente lo que nadie ha verificado.

## ⚠️ Antes de usar los IDs: `BUG-01` y `BUG-02` existen dos veces

El identificador `BUG-01` designa **dos bugs distintos** y `BUG-02` también. Es un defecto de esta misma
documentación, no del código, y produce ambigüedad en cualquier tablero que los copie tal cual:

| ID ambiguo | Qué es realmente | Carpeta |
|---|---|---|
| `BUG-01` | `DELETE /api/Categorias/{id}` borra en cascada movimientos y presupuestos | [`backend-tests/issues/`](backend-tests/issues/BUG-01-delete-categoria-borra-en-cascada-movimientos-presupuestos.md) |
| `BUG-01` | El JWT no trae el claim corto `role` ni `iat` | [`HU01/issues/`](HU01/issues/BUG-01-jwt-sin-claim-role-corto.md) |
| `BUG-02` | `POST /api/Categorias` persiste con `IdHogar = 0` si falta el claim | [`backend-tests/issues/`](backend-tests/issues/BUG-02-create-categoria-IdHogar-0-sin-claim.md) |
| `BUG-02` | `PUT /api/Hogares/{id}` sin `[Authorize(Roles = "Admin")]` | [`HU01/issues/`](HU01/issues/BUG-02-put-hogares-sin-restriccion-rol.md) |

**Propuesta para MVP 3 (tarea de 30 min, parte de S0):** renombrar con prefijo de origen antes de abrir los
issues en GitHub, porque después de importarlos el ID es irreversible.

| Prefijo | Alcance | Ejemplo |
|---|---|---|
| `CAT-01` … `CAT-04` | Suite de categorías (`backend-tests`) | `CAT-01` = borrado en cascada |
| `AUTH-01` … `AUTH-02` | HU-01 (auth / hogares) | `AUTH-01` = claim `role` |
| `SEC-01` … `SEC-10` | Seguridad (ya es único) | — |
| `DEMO-01` … `DEMO-11` | Demo end-to-end (ya es único) | — |

En este documento los IDs ambiguos se citan con su carpeta: `CAT-01`, `AUTH-01`, `AUTH-02`.

---

## 1. Vista consolidada de los 28 issues

Estado: 🔴 Crítica · 🔴 Alta · 🟠 Alta · 🟡 Media · 🟢 Baja · ✅ Corregido

| ID | Hallazgo | Origen | Sev. | Esfuerzo | Cerrado en MVP 3 con |
|---|---|---|---|---|---|
| **SEC-01** | Clave de firma JWT en texto plano y versionada | [issue](SEGURIDAD/issues/SEC-01-clave-jwt-hardcodeada.md) | 🔴 Crítica | ~15 min | Clave fuera del repo + rotada + `Vuln_SEC01_…` en rojo |
| **SEC-02** | Contraseña de PostgreSQL hardcodeada, `5432:5432` publicado | [issue](SEGURIDAD/issues/SEC-02-contrasena-postgres-hardcodeada.md) | 🔴 Crítica | ~20 min | `.env` no versionado + puerto cerrado + test en rojo |
| **DEMO-01** | `docker compose up --build` falla: falta el contexto `../frontend` | [issue](DEMO-E2E/issues/DEMO-01-compose-up-build-falla-sin-frontend.md) | 🔴 Alta | ~30 min | `docker compose up --build` levanta API + base en máquina limpia |
| **DEMO-02** | Educación Financiera vacía: la migración no siembra tips | [issue](DEMO-E2E/issues/DEMO-02-educacion-financiera-sin-contenido-sembrado.md) | 🔴 Alta | ~1 h | `GET /api/TipsFinancieros` devuelve filas en base limpia |
| **DEMO-04** | La API no entrega alerta de presupuesto excedido | [issue](DEMO-E2E/issues/DEMO-04-sin-alerta-de-presupuesto-excedido.md) | 🔴 Alta | ~4 h | DTO con `montoGastado` + `nivelAlerta` |
| **CAT-01** | `DELETE /api/Categorias/{id}` borra en cascada el historial financiero | [issue](backend-tests/issues/BUG-01-delete-categoria-borra-en-cascada-movimientos-presupuestos.md) | 🔴 Alta | ~2 h | `409` y los datos sobreviven |
| **DEMO-03** | La API se cae en el primer arranque sobre base limpia | [issue](DEMO-E2E/issues/DEMO-03-api-cae-al-arrancar-en-base-limpi.md) | 🔴 Alta | ~1 h | Arranque limpio sin reinicio |
| **SEC-03** | Cero cabeceras de seguridad | [issue](SEGURIDAD/issues/SEC-03-sin-cabeceras-de-seguridad.md) | 🟠 Alta | ~30 min | `CP-S-37` en verde |
| **SEC-04** | Sin rate limiting ni bloqueo de cuenta en login/registro | [issue](SEGURIDAD/issues/SEC-04-sin-rate-limit-en-login.md) | 🟠 Alta | ~1 h | `CP-S-38` en verde |
| **AUTH-02** | `PUT /api/Hogares/{id}` sin restricción de rol | [issue](HU01/issues/BUG-02-put-hogares-sin-restriccion-rol.md) | 🟠 Alta | ~15 min | `CP-15` pasa de `204` a `403` |
| **AUTH-01** | JWT sin claim corto `role` ni `iat` | [issue](HU01/issues/BUG-01-jwt-sin-claim-role-corto.md) | 🟡 Media | ~1 h | Contrato de claims cumplido + frontend coordinado |
| **SEC-05** | Texto libre sin sanear y `Contenido` de tips sin cota | [issue](SEGURIDAD/issues/SEC-05-campos-texto-sin-saneamiento.md) | 🟡 Media | ~1 h | `[StringLength]` + acuerdo con frontend |
| **SEC-06** | `Rol` es texto libre sin lista blanca | [issue](SEGURIDAD/issues/SEC-06-rol-sin-lista-blanca.md) | 🟡 Media | ~30 min | Enum + `400` ante valor inválido |
| **SEC-07** | JWT sin `jti`, sin revocación, `ClockSkew` de 5 min | [issue](SEGURIDAD/issues/SEC-07-jwt-sin-revocacion-ni-clock-skew.md) | 🟡 Media | ~4 h | Vida corta + refresh + `ClockSkew = Zero` |
| **SEC-08** | El compose arranca la API en `Development` | [issue](SEGURIDAD/issues/SEC-08-aspnet-environment-development.md) | 🟡 Media | ~30 min | `swagger.json` devuelve 404 fuera de local |
| **SEC-09** | API y base de datos sin TLS, `5432:5432` al host | [issue](SEGURIDAD/issues/SEC-09-http-sin-tls-en-contenedor.md) | 🟡 Media | ~1 h | TLS en el borde documentado + puertos en loopback |
| **CAT-02** | `POST /api/Categorias` persiste con `IdHogar = 0` | [issue](backend-tests/issues/BUG-02-create-categoria-IdHogar-0-sin-claim.md) | 🟡 Media | ~30 min | `400` sin persistir huérfanos |
| **CAT-03** | `Categoria.Tipo` sin lista blanca | [issue](backend-tests/issues/BUG-03-categorias-sin-validacion-tipo.md) | 🟡 Media | ~30 min | Solo `Ingreso`/`Gasto` |
| **CAT-04** | Nombres de categoría duplicados en un mismo hogar | [issue](backend-tests/issues/BUG-04-create-categorias-duplicadas-nombre.md) | 🟡 Media | ~1 h | `409` + índice único |
| **DEMO-05** | `Movimiento.Tipo` sin lista blanca | [issue](DEMO-E2E/issues/DEMO-05-tipo-de-movimiento-sin-validacion.md) | 🟡 Media | ~1 h | Enum de tipo (desbloquea `DEMO-04`) |
| **DEMO-06** | `Presupuesto` no expone consumo ni porcentaje | [issue](DEMO-E2E/issues/DEMO-06-presupuesto-sin-montogastado-ni-porcentaje.md) | 🟡 Media | (junto a `DEMO-04`) | `PresupuestoDto` |
| **DEMO-07** | No hay endpoint de tablero o resumen | [issue](DEMO-E2E/issues/DEMO-07-sin-endpoint-de-tablero-o-resumen.md) | 🟡 Media | ~6 h | `GET /api/Tablero` o decisión documentada |
| **DEMO-08** | La remesa solo se distingue por `origenEmisora` | [issue](DEMO-E2E/issues/DEMO-08-remesa-solo-por-convencion-de-origenemisora.md) | 🟡 Media | ~3 h | Enum `OrigenIngreso` + filtro |
| **DEMO-09** | `MetaAhorro` sin faltante, avance ni ritmo mensual | [issue](DEMO-E2E/issues/DEMO-09-meta-sin-faltante-ni-ritmo-mensual.md) | 🟡 Media | ~3 h | `MetaAhorroDto` con reglas de borde |
| **DEMO-10** | Cada tip apunta a una `Categoria` que es por hogar | [issue](DEMO-E2E/issues/DEMO-10-sin-servicio-de-tips.md) | 🟡 Media | ~3 h | Desacoplar + bajar el permiso |
| **SEC-10** | CI sin escaneo de secretos ni tests; `AllowedHosts: "*"` | [issue](SEGURIDAD/issues/SEC-10-higiene-de-configuracion-y-ci.md) | 🟢 Baja | ~45 min | `gitleaks` + `dotnet test` en el workflow |
| **DEMO-11** | `EF Core.Relational` 8.0.11 vs 8.0.30 y SDK sin `global.json` | [issue](DEMO-E2E/issues/DEMO-11-conflicto-de-version-efcore-y-sdk-sin-fijar.md) | 🟢 Baja | ~30 min | Sin `MSB3277` + SDK fijado |
| **BUG-05-01** | `GET /api/Presupuestos?anio=&mes=` → `500` con `MesAnio` por defecto | [issue](HU05/issues/BUG-05-01-filtro-presupuestos-500-postgres.md) | 🔴 Alta | — | ✅ **Corregido** (filtro por rango UTC). Pendiente el seguimiento de `MesAnio` obligatorio |

**Los dos `🔴 Crítica` (SEC-01, SEC-02) y los dos `🟠 Alta` de seguridad (SEC-03, SEC-04) tienen un coste
de reputación disproportionate: son verificables por cualquiera que lea el repositorio.**

---

## 2. P0 — Antes de volver a presentar o entregar (5 ítems, ~1 día)

Orden imports: primero los secretos (rotar es irreversible y ventana de exposición), después los tres
bloqueantes de demo, y el de datos porque `CAT-01` destruye información real de familias.

| # | Ítem | Por qué es P0 | Esfuerzo |
|---|---|---|---|
| 1 | **SEC-01** + **SEC-02** — mover `Jwt:Key` y `POSTGRES_PASSWORD` a variables de entorno y **rotar ambos** | La clave de firma está en un archivo versionado: cualquiera con el repo puede firmar un token `Admin` de cualquier hogar. La ventana de exposición ya está abierta; cada día sin rotar la extiende | ~35 min |
| 2 | **CAT-01** — impedir el borrado en cascada de categorías | Es el único issue de **pérdida de datos irreversible** del inventario. Un clic equivocado borra el historial financiero de un hogar | ~2 h |
| 3 | **DEMO-01** — `profiles` en el compose o precondición explícita | Es el paso 1 del guion y del checklist. Si falla, el jurado ve fallar el arranque | ~30 min |
| 4 | **DEMO-02** + **DEMO-10** — sembrar tips **y** desacoplar el modelo de `EducacionFinanciera` | Hoy están **doblemente bloqueados**: no hay contenido y, aunque lo hubiera, no hay forma limpia de cargarlo porque cada tip exige una `Categoria` de una familia. Resolver `DEMO-10` primero | ~4 h |
| 5 | **DEMO-04** + **DEMO-06** — `PresupuestoDto` con `montoGastado`, `porcentajeConsumido`, `nivelAlerta` | Es el *"momento clave de la demo"* del guion y hoy depende 100 % de que el frontend lo detecte. **Requiere `DEMO-05` antes** (el filtro por `tipo` es sensible a mayúsculas y un `"gasto"` en minúscula rompería el cálculo) | ~4 h |

> **Dependencias que no se ven si se lee issue por issue:** `DEMO-05` → `DEMO-04`/`DEMO-06`;
> `DEMO-10` → `DEMO-02`; `SEC-01` → `SEC-07` (rotar invalida los tokens emitidos, que es lo deseado);
> `DEMO-11` → todos los tests de integración (alinear Npgsql cambia el comportamiento real).

---

## 3. P1 — Seguridad y autorización (~10 h de desarrollo)

El plan de remediación de la auditoría ya está estimado y es reproducible aquí
([`Auditoria_Seguridad.md` §8](SEGURIDAD/Auditoria_Seguridad.md)):

| # | Ítem | Esfuerzo | Criterio de cierre |
|---|---|---|---|
| 1 | **SEC-03** — middleware de cabeceras (`nosniff`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `Cache-Control: no-store`, HSTS fuera de local) | ~30 min | `CP-S-37` en verde. La CSP **no va aquí**: la API no sirve HTML |
| 2 | **SEC-04** — `AddRateLimiter` (5/min por IP) + contador de intentos con bloqueo | ~1 h | `CP-S-38` en verde. El bloqueo por cuenta necesita batería HTTP, no xUnit |
| 3 | **AUTH-02** — `[Authorize(Roles = "Admin")]` en `PUT /api/Hogares/{id}` | ~15 min | `CP-15` pasa de `204` a `403` |
| 4 | **AUTH-01** — claim `role` corto + `iat` | ~1 h | ⚠️ **rompe el frontend**: hay que cambiar `payload.role` → `payload[role largo]`, o limpiar el mapa de claims en `Program.cs` y ajustar ambos lados. Coordinar antes de tocar |
| 5 | **SEC-07** — `ClockSkew = Zero`, vida corta, `jti` + refresh | ~4 h | Un cambio de rol surte efecto antes de que expire el token |
| 6 | **SEC-08** — `ASPNETCORE_ENVIRONMENT=Production` por defecto | ~30 min | `swagger.json` devuelve 404 |
| 7 | **SEC-09** + **SEC-02** (puerto) — TLS en el borde, puertos atados a loopback | ~1 h | El JWT deja de viajar en claro |
| 8 | **SEC-05** + **SEC-06** + **CAT-03** — listas blancas y cotas de longitud | ~1.5 h | ⚠️ Revisar `UpdateUsuarioRequest.Nombre` y `AddMemberRequest.Rol` al activar la validación implícita |

**Nota operativa para MVP 3:** los tests con prefijo `Vuln_SECxx_` **afirman que la vulnerabilidad sigue
presente**. Pasarán a rojo en el momento exacto en que se corrija el hallazgo. Quien arregle un `SEC` tiene
que **invertir ese test en el mismo PR**: es el detector, no un falso positivo.

---

## 4. P2 — Contrato de API: lo que el material promete y la API no entrega

Cinco features (`DEMO-04`, `06`, `07`, `08`, `09`, `10`) no son bugs: son **capacidades que el guion y el
README del frontend dan por hechas** y que la API no soporta. La decisión de MVP 3 no es solo *implementarlas*
— es **elegir cuáles entran y corregir el material de las que no**.

| ID | Prometido en | Realidad | Costo de no decidir |
|---|---|---|---|
| **DEMO-06/04** | "la barra de presupuesto muestra el 40 %", "aparece la alerta" | `Presupuesto` solo tiene `montoLimite` y `mesAnio` | El frontend calcula con N+1 de llamadas; en gama media Android con 1 000+ movimientos se nota |
| **DEMO-07** | "Dashboard con tarjetas y gráficas" | No hay endpoint de agregado; el cliente descarga todo | Crece con la base. Además, sin él el tablero no escala |
| **DEMO-08** | "tarjeta de remesas", "vistas de remesas" | `origenEmisora` vacío o no es la heurística | Un salario con el campo diligenciado cuenta como remesa: **$1 600 en lugar de $400** |
| **DEMO-09** | "la app calcula el progreso, lo que falta y el ritmo mensual" | `MetaAhorro` expone `montoActual` y nada más | Tres reglas de borde sin decidir (ver §5) |
| **DEMO-10** | "el contenido llega cuando es relevante" | Contenido global con FK a tabla por hogar | Sin `Tema`/`Icono` no hay forma de sembrar nada (§2, ítem 4) |
| **DEMO-02** | "tip relacionado con la actividad de la familia" | No hay campo que describa a qué actividad aplica un tip, ni endpoint que lo recomiende | `CP-D37` es **imposible** de satisfying con el modelo actual |

**Mejora transversal asociada: paginación.** Ningún listado la implementa (`page`/`pageSize` se ignoran en
los cuatro `GET`) y es la raíz común de `DEMO-07` y del riesgo de rendimiento. Ver §5, decisión 9.

---

## 5. Decisiones pendientes del equipo (`CONFIRMAR-CON-EQUIPO`)

**14 casos marcados `CONFIRMAR-CON-EQUIPO`** (§5.1 y §5.2), más 7 decisiones de diseño que ninguna batería
puede resolver (§5.3). No son bugs porque QA no puede decidir cuál es el comportamiento correcto: los
criterios de aceptación oficiales de HU-05 y de los listados nunca se publicaron. **Cada una es un `400` que
puede no escribirse nunca.** Resolverlas es la tarea más barata de MVP 3 (una reunión) y la que más riesgo
deja abierto si no se hace.

> Los 14 son 8 de HU-05 + 8 de Filtros/Paginación, menos 2 duplicados: `CP-16` es el mismo caso que `FP-09`
> y `CP-17` el mismo que `FP-10`.

### 5.1 Presupuestos (HU-05) — comportamiento real medido

| Caso | Comportamiento real hoy | Pregunta |
|---|---|---|
| `CP-06` | Un rol `Miembro` crea, edita y borra presupuestos (`201`/`204`) | ¿Solo `Admin` debe gestionarlos? |
| `CP-10` | `MontoLimite: 0` → `201 Created` | ¿El límite debe ser estrictamente positivo? |
| `CP-11` | `MontoLimite: -50.00` → `201 Created` | ¿Se rechaza el negativo? |
| `CP-12` | Sin `MesAnio` → `201` con `0001-01-01` | ¿El mes es obligatorio? |
| `CP-13` | Misma categoría + mismo mes → `201` (duplicado) | ¿Debe ser único por categoría y mes? |
| `CP-16` = `FP-09` | `?anio=2026` sin mes → devuelve **todo** | ¿Debe filtrar por año solo? |
| `CP-17` = `FP-10` | `?mes=9` sin año → devuelve **todo** | ¿Debe filtrar por mes solo? |
| `CP-24` | `PUT` con `MontoLimite: 0` y luego `-10` → `204` | ¿Igual que en creación? |

> `CP-12` tiene consecuencia **medida**: el `MesAnio` por defecto (`-infinity` en PostgreSQL) fue la causa
> raíz del `500` de `BUG-05-01`. Si se marca el mes como obligatorio, ese `500` no puede volver a ocurrir
> por esa vía — y es el seguimiento natural de un bug ya corregido.

### 5.2 Movimientos y listados (Filtros/Paginación)

| Caso | Comportamiento real hoy | Pregunta |
|---|---|---|
| `FP-05` | `?tipo=gasto` (minúsculas) → **vacío**; el filtro es sensible a mayúsculas | ¿Debe ser case-insensitive? |
| `FP-13` … `FP-16` | `page`/`pageSize` se ignoran en los 4 listados; sin campo `total` | ¿Paginación es requisito del MVP o *works as designed*? |
| `FP-17` | `?page=-1&pageSize=abc` → `200` con todo o `400` según binding | Sin contrato de paginación no hay respuesta única |

> `FP-05` parece menor y **bloquea `DEMO-04`**: si `MontoGastado` se calcula con `tipo == "Gasto"`, un
> movimiento guardado como `"gasto"` no se contaría y el alerta saltaría tarde o no saltaría.

### 5.3 Decisiones de diseño que también están abiertas

| Decisión | Alternativas | Impacto |
|---|---|---|
| **Paginación** | (a) implementar con `total`; (b) declarar *works as designed* y documentar el techo de volumen | Decide si `DEMO-07` entra en MVP 3 |
| **Endpoint de tablero** | (a) construir `GET /api/Tablero`; (b) mantener el cálculo en cliente y decirlo en el guion | ~6 h de API |
| **Tip contextual** | (a) campo `Tema` + endpoint de recomendación; (b) tips genéricos sin relación con la actividad | El guion promete "contenido relevante" |
| **`MesesRestantes` vencido** | `0` o negativo | `DEMO-09` |
| **`RitmoMensualSugerido` con `Faltante = 0`** | `0` o `null` | La `DEMO_GUIDE` promete "el ritmo mensual se ve en 0" — confirmar |
| **`MetaAhorro.Estado`** | Es texto libre y `PUT` permite escribirlo a mano | Mismo patrón que `DEMO-05`/`CAT-03` |
| **`MesAnio` obligatorio** | Sí / no | Seguimiento de `BUG-05-01` |

---

## 6. Deuda de proceso: no tiene issue y por eso se pierde entre sprints

Estas cinco no son bugs del producto. Son las razones por las que los bugs anteriores **volvieron a
entrar sin que nadie lo notara**. No tienen archivo en `issues/` y por eso ningún tablero las va a mostrar.

### 6.1 La suite xUnit usa EF Core InMemory y dos bugs reales se escaparon

| Bug | Por qué InMemory no lo detectó |
|---|---|
| `CAT-01` (borrado en cascada) | InMemory **no impone** `ON DELETE CASCADE`; el test `Delete_DeMismoHogar_…` pasa en verde mientras PostgreSQL borra el historial |
| `BUG-05-01` (`500` por `-infinity`) | El literal `integer out of range` es de PostgreSQL; en memoria la aritmética es correcta |

**Mejora para MVP 3:** una suite de integración con **PostgreSQL real** (Testcontainers o la instancia del
compose) que cubra integridad referencial, rangos de fechas y tipos nativos. Sin ella, un `94/94 en verde`
sigue sin decir nada sobre la base de datos donde viven los datos de las familias.

Relacionado: `DEMO-11` (EF Core 8.0.11 vs 8.0.30, sin `global.json`) significa que los tests compilaron
con el **SDK 10.0.302**, no con el 8 documentado. Si Npgsql y EF divergen, InMemory puede no reflejar el
comportamiento real: es la misma clase de diferencia que produjo `BUG-05-01`.

### 6.2 CI no ejecuta los tests

`.github/workflows/ci.yml` solo hace `restore`, `build` y `docker build`. **Los 94 tests no corren en CI**,
así que una regresión se descubre en la máquina de quien desarrolla, si se da cuenta. Parte de `SEC-10`.

### 6.3 El frontend nunca se ha probado ni auditado

- **0 tests ejecutados**: los 2 casos de `App.test.jsx` (Vitest) siguen sin correr porque Node.js no está
  instalado en el entorno de QA.
- **0 auditoría**: el repo `RemesaSmartSV/frontend` no está clonado junto a este, así que **no se ha
  verificado** el renderizado de texto (riesgo de XSS almacenado de `SEC-05`), ni la CSP, ni el uso de
  `localStorage`.
- Los **6 checks de la demo que fallan** y whose esperado es *"la API entrega X"* **no son bugs del
  backend** verificados: son riesgos de demostración que podrían estar compensados por el frontend. Desde
  aquí **no se puede afirmar** cuáles lo están y cuáles no.
- El `README` del frontend anuncia backend en `localhost:5203` mientras el compose lo publica en `8080`:
  discrepancia **sin verificar** que puede explicar un fallo de arranque del frontend.

### 6.4 La documentación afirma capacidades que no existen

Verificado en la [corrida de la demo](DEMO-E2E/README.md). Para MVP 3, corregir el material o implementar
lo prometido:

| Afirmación | Dónde | Estado |
|---|---|---|
| "`docker compose up --build` levanta los tres servicios" | Guion §5.5, §8, checklist | ❌ Falla sin el repo hermano |
| "el contenido llega cuando es relevante, no cuando es bonito" | Guion §3, paso 4 | ❌ No existe tip por actividad |
| "aparece la alerta" al exceder presupuesto | Guion §8, paso 8 | ❌ Sin soporte en la API |
| "la app calcula el progreso, lo que falta y el ritmo mensual" | Guion §3, paso 3 | ❌ La entidad no expone ninguno |
| "el token se invalida" al cerrar sesión | `DEMO_GUIDE.md` §10 | ❌ Sigue válido 8 h |
| "tabla paginada" · "Buscar por texto" · "Filtrar por fecha" | `DEMO_GUIDE.md` §5, §6 | ❌ La API no pagina ni busca texto |
| "JWT con claims `idUsuario`, `idHogar`, rol y correo" | Guion §5.5 | ⚠️ El rol viaja con el URI largo |
| "Entity Framework Core 8.0.30" | `backend/README.md` | ⚠️ El build resuelve `Relational` 8.0.11 |
| "los umbrales de rendimiento" | [`PERF`](PERF/README.md) | ⚠️ No hay criterios de aceptación oficiales |

### 6.5 Los identificadores de issue se repiten

`BUG-01` y `BUG-02` están duplicados entre carpetas (§Advertencia). Sin corregirlo, dos tickets con el mismo
ID acabarán en el mismo tablero.

---

## 7. Propuesta de roadmap

Cuatro bloques. Los efforts son de desarrollo, no incluyen revisión ni QA.

| Bloque | Contenido | Esfuerzo | Por qué en ese orden |
|---|---|---|---|
| **S0 · Desbloquear** | `SEC-01`, `SEC-02`, `CAT-01`, `DEMO-01`, `DEMO-05`, `DEMO-10`+`DEMO-02`, `DEMO-04`+`DEMO-06` | ~1.5 días | Los secretos primero (la ventana sigue abierta), datos después, y los bloqueantes de demo al final porque `DEMO-04` depende de `DEMO-05` y `DEMO-02` de `DEMO-10` |
| **S1 · Seguridad** | `SEC-03`, `SEC-04`, `AUTH-02`, `SEC-07`, `SEC-08`, `SEC-09`, `SEC-05`, `SEC-06`, `CAT-03` | ~2 días | Estima tomada del plan de remediación de la auditoría, que ya está escrito |
| **S2 · Contrato** | `DEMO-07`, `DEMO-08`, `DEMO-09`, `CAT-02`, `CAT-04`, paginación (según §5) | ~3 días | Solo después de haber **decidido** §5; implementar sin decidir es lo que generó los 14 `CONFIRMAR` |
| **S3 · Calidad** | `DEMO-11`, `SEC-10`, suite de integración PostgreSQL (6.1), tests de frontend (6.3), criterios de rendimiento | ~2 días | Sella el proceso: sin esto, S0–S2 vuelven a abrir huecos |

**Antes de arrancar S0:** una reunión de 45 min para §5. Todo el bloque S2 depende de esas respuestas, y
las 14 preguntas ya tienen el comportamiento real medido y documentado — la reunión es para **decidir**, no
para investigar.

## 8. Definición de "cerrado" para MVP 3

Un issue está cerrado cuando se cumplen **las cuatro** condiciones. La cuarta es la que evita que el backlog
vuelva a llenarse:

1. El código está corregido y revisado.
2. Hay un caso de prueba que **falla antes** y **pasa después**.
3. Si el caso era `Vuln_SECxx_` (afirma que la vulnerabilidad sigue presente), **se invirtió** en el mismo PR.
4. Se actualizó la documentación afectada: `README`, `DEMO_GUIDE`, guion o checklist, según lo que afirme.

La condición 4 es la que cierra el círculo de §6.4: hoy el material de presentación afirma capacidades que
la API no tiene, y eso no se detecta con tests porque **los tests no leen el material**.

## 9. Trazabilidad

| Entrega de origen | Issues | Informe |
|---|---|---|
| Auditoría de seguridad (#76) | `SEC-01` … `SEC-10` | [`SEGURIDAD/Auditoria_Seguridad.md`](SEGURIDAD/Auditoria_Seguridad.md) · [42 casos](SEGURIDAD/Casos_Prueba_Seguridad.md) |
| Demo end-to-end (#80) | `DEMO-01` … `DEMO-11` | [`DEMO-E2E/README.md`](DEMO-E2E/README.md) · [40 checks](DEMO-E2E/resultados_DEMO_E2E.csv) |
| Suite de categorías | `CAT-01` … `CAT-04` | [`backend-tests/`](backend-tests/issues/) |
| HU-01 auth/hogares | `AUTH-01`, `AUTH-02` | [`HU01/README.md`](HU01/README.md) · [27 casos](HU01/Ejecucion_Pruebas_HU01_resultados.md) |
| HU-05 presupuestos | `BUG-05-01` ✅ | [`HU05/Casos_Prueba_HU05.md`](HU05/Casos_Prueba_HU05.md) · [27 casos](HU05/resultados_HU05.csv) |
| Filtros/paginación | (sin issue: decisiones §5.2) | [`FILTROS-PAGINACION/README.md`](FILTROS-PAGINACION/README.md) · [17 casos](FILTROS-PAGINACION/resultados_FILTROS_PAGINACION.csv) |
| Performance | (sin issue: 1 caso saltado) | [`PERF/README.md`](PERF/README.md) · [8 casos](PERF/resultados_PERF.csv) |

Conteo de pruebas hoy: **213 casos · 198 en verde · 14 en rojo · 1 saltado** ([reporte completo](../test-report.md)).
