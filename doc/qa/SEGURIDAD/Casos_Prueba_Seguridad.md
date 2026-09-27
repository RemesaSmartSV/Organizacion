# Casos de Prueba — Auditoría de Seguridad Básica · RemesaSmart SV

**Issue:** [#76](https://github.com/RemesaSmartSV/Organizacion/issues/76)
**Alcance:** XSS · CSRF · tokens JWT · contraseñas/secrets hardcodeados · cabeceras de seguridad (+ autorización/IDOR e inyección SQL como verificación transversal)
**Fecha:** domingo 27 de septiembre de 2026
**Ejecución:** automatizada en xUnit contra el código real del backend (`backend.Tests/SeguridadTests.cs`, EF Core InMemory + `JwtSecurityTokenHandler` + reflexión sobre el ensamblado)

---

## Cómo se ejecuta

```powershell
# Suite completa (94 casos: 52 de QA previa + 42 de seguridad)
dotnet test backend.Tests\backend.Tests.csproj

# Solo los 42 casos de esta auditoría
dotnet test backend.Tests\backend.Tests.csproj --filter "FullyQualifiedName~Seguridad"

# Regenerar los artefactos de esta carpeta (CSV, JSON y evidencia_raw.log)
powershell -ExecutionPolicy Bypass -File doc\qa\SEGURIDAD\Generar_Resultados_Seguridad.ps1
```

**Convención de nombres (importante para el equipo):**
- Los casos que **verifican un control que existe** se llaman como el control (`Jwt_...`, `Autorizacion_...`, `ContrasenaHash_...`). Se quedan en verde mientras el control siga bien.
- Los casos que **documentan un hueco** se prefijan con `Vuln_SECxx_` y **afirman que la vulnerabilidad está presente**. Cuando se corrija el hallazgo, ese test pasará a rojo: hay que eliminarlo o invertirlo en la corrección (es la señal de que el arreglo está completo). Lista: §"Hallazgos" más abajo.

## Resultado por área

| Área | Casos | PASS | NO CONFORME | Severidad máxima |
|------|-------|------|--------------|------------------|
| Tokens JWT | 10 | 10 | — | 🔴 Crítica (SEC-01) |
| Contraseñas de usuario (hashing) | 5 | 5 | — | ✅ Conforme |
| CSRF / Autorización / IDOR | 12 | 12 | — | 🟡 Media (SEC-06) |
| XSS | 5 | 5 | — | 🟡 Media (SEC-05) |
| Cabeceras / Secretos / Pipeline | 10 | 10 | — | 🔴 Crítica (SEC-01/02) |
| **Total** | **42** | **42** | **0** | — |

> Todos los casos pasan porque los tests `Vuln_` **afirman la existencia** del hueco. El "NO CONFORME" está en el hallazgo, no en el color del test. Detalle por caso en la columna *Veredicto*.
> Agrupación temática (esta tabla) frente a agrupación por clase de test (`SeguridadJwtTests` 10, `SeguridadContrasenasTests` 5, `SeguridadAutorizacionTests` 9, `SeguridadXssTests` 5, `SeguridadConfiguracionTests` 13): el reparto difiere porque tres tests de configuración (CORS, orden del pipeline, bearer sin cookies) pertenecen temáticamente a CSRF/autorización. Los **42 son los mismos** en ambas vistas.

---

## A. Tokens JWT (10 casos)

| ID | Caso (test) | Qué comprueba | Esperado | Obtenido | Veredicto |
|----|-------------|---------------|----------|----------|-----------|
| CP-S-01 | `Jwt_EmitidoPorLogin_PasaLaValidacionConIssuerAudienceVigenciaYFirmaCorrectas` | El token real de `LoginAsync` pasa `JwtSecurityTokenHandler.ValidateToken` con los mismos parámetros que usa la API | Válido, `iss` correcto, claims `idUsuario`/`idHogar` legibles | Idéntico | ✅ CONFORME |
| CP-S-02 | `Jwt_ElRolDelTokenEsElQueAutorizaLasOperacionesRestringidas` | El rol del token es el que concede operaciones Admin | `HasClaim(ClaimTypes.Role=Admin)` → `true` | Idéntico | ✅ CONFORME |
| CP-S-03 | `Jwt_FirmadoConUnaClaveDistintaEsRechazadoComoTokenFalsificado` | Token falsificado con otra clave y `Rol=Admin` no se acepta | Rechazado | `SecurityTokenException` | ✅ CONFORME |
| CP-S-04 | `Jwt_AlterarElRolYRefirmarConOtraClaveLanzaSecurityTokenException` | Alterar el claim de rol y re-firmar con clave ajena no bypasea la validación | Excepción de seguridad | Excepción | ✅ CONFORME |
| CP-S-05 | `Jwt_ConIssuerDistintoEsRechazado` | `iss` incorrecto | Rechazado | Rechazado | ✅ CONFORME |
| CP-S-06 | `Jwt_ConAudienceDistintaEsRechazado` | `aud` incorrecto | Rechazado | Rechazado | ✅ CONFORME |
| CP-S-07 | `Jwt_VencidoEsRechazado` | Token vencido hace 30 min | Rechazado | Rechazado | ✅ CONFORME |
| CP-S-08 | `Jwt_LaVigenciaEsDeOchoHorasYNoMas` | Vigencia documentada | Entre 7 h 54 min y 8 h | 8 h | ✅ CONFORME |
| CP-S-09 | `Jwt_NoIncluyeClaimJtiPorLoQueNoSePuedeRevocarUnTokenIndividualmente` | Existe `jti` para revocación | `jti` presente | `jti` **ausente** | 🟡 **SEC-07** (medios) |
| CP-S-10 | `Vuln_SEC07_UnTokenVencidoHaceMenosDeCincoMinutosTodaviaSeAceptaPorElClockSkewPorDefecto` | `ClockSkew` explícito en la configuración | Rechaza también con 2 min de retraso | Con `ClockSkew=5min` (por defecto) **lo acepta** | 🟡 **SEC-07** (medios) |

> Nota: el `ClockSkew` de 5 min es el valor por defecto de la librería y no está fijado en `Program.cs:49-58`; por eso el caso 07 con `TimeSpan.Zero` pasa y el 10 documenta el margen real.

## B. Contraseñas de usuario (5 casos)

| ID | Caso (test) | Qué comprueba | Esperado | Obtenido | Veredicto |
|----|-------------|---------------|----------|----------|-----------|
| CP-S-11 | `ContrasenaHash_UsaPbkdf2ConSalYNoContieneLaClaveEnClaro` | Algoritmo y formato del hash (`PasswordHasher`, PBKDF2) | Prefijo `AQ`, la clave no aparece en el hash | Idéntico | ✅ CONFORME |
| CP-S-12 | `ContrasenaHash_DosUsuariosConLaMismaClaveTienenHashesDistintosPorLaSal` | Sal aleatoria por usuario | Hashes distintos; ambos verifican | Idéntico | ✅ CONFORME |
| CP-S-13 | `ContrasenaHash_LaVerificacionRechazaLaClaveIncorrecta` | Verificación en login | `PasswordVerificationResult.Failed` | Idéntico | ✅ CONFORME |
| CP-S-14 | `ContrasenaHash_NuncaSeSerializaEnLasRespuestasJsonDeLaApi` | `Usuario` serializado sin el hash (`[JsonIgnore]`) | Sin `ContrasenaHash` ni prefijo `AQAAAA` | Idéntico | ✅ CONFORME |
| CP-S-15 | `LoginResponse_NoExponeLaContrasenaNiElHashEnNingunCampo` | Respuesta de login sin datos sensibles | Sin contraseña ni hash | Idéntico | ✅ CONFORME |

> El *hardcodeado* de contraseñas/secretos no está en esta sección: son claves de infraestructura (JWT y PostgreSQL), se tratan en §E.

## C. CSRF / Autorización / IDOR (12 casos)

| ID | Caso (test) | Qué comprueba | Esperado | Obtenido | Veredicto |
|----|-------------|---------------|----------|----------|-----------|
| CP-S-16 | `Configuracion_LaApiUsaBearerYNoCookiesPorLoQueElCsrfNoEsExplotable` | Sin cookies, sesión ni antiforgery | Solo `AddJwtBearer` | Idéntico | ✅ CONFORME (CSRF N/A) |
| CP-S-17 | `Configuracion_CorsSoloPermiteElOrigenDelFrontendSinWildcardNiCredenciales` | CORS con origen fijo, sin `*` ni credenciales | `WithOrigins("http://localhost:5173")` y nada más | Idéntico | ✅ CONFORME |
| CP-S-18 | `Configuracion_LaValidacionOcurreAntesDeAutorizarYAntesDeMapearLosControllers` | Orden del pipeline | `UseAuthentication` < `UseAuthorization` < `MapControllers` | Idéntico | ✅ CONFORME |
| CP-S-19 | `Autorizacion_TodoControllerSinAuthorizeDeClaseExponeSoloEndpointsDeclaradosDeFormaExplicita` | Ningún controller queda abierto por olvido | Solo `AuthController` y `TipsFinancierosController` sin `[Authorize]` de clase, y cada endpoint declara `[AllowAnonymous]`/`[Authorize]` | Idéntico | ✅ CONFORME |
| CP-S-20 | `Autorizacion_LosEndpointsPublicosSonSoloLosDelLoginYRegistroYLosTipsDeLectura` | Superficie anónima real | 4 endpoints: `Auth.Register`, `Auth.Login`, `Tips.GetTips`, `Tips.GetTip` | Idéntico | ✅ CONFORME |
| CP-S-21 | `Autorizacion_NingunEndpointQuedaAnonimoPorHerenciaOErrorDeOmision` | Invariante global: todo endpoint o es anónimo explícito, o hereda `[Authorize]` | Lista vacía | Idéntico | ✅ CONFORME |
| CP-S-22 | `Autorizacion_LasOperacionesCriticasDeUsuariosTipsYHogaresExigenRolAdmin` | Atributo `Roles="Admin"` en las 7 operaciones sensibles | Las 7 con `Admin` | Idéntico | ✅ CONFORME |
| CP-S-23 | `Autorizacion_ElHogarYElUsuarioDeUnMovimientoSeTomanDelTokenYNoDelCuerpo` | Mass assignment / IDOR: `IdHogar=999` en el body | Se persiste el del token (42) y el usuario del token (7) | Idéntico | ✅ CONFORME |
| CP-S-24 | `Autorizacion_UnaCategoriaNoPuedeCrearseEnElHogarDeOtroUsuarioAunqueVengaEnElCuerpo` | IDOR en creación de categorías | Se fuerza `IdHogar` del token | Idéntico | ✅ CONFORME |
| CP-S-25 | `Autorizacion_UnMiembroNoCumpleElAtributoAdminParaCrearUsuarios` | Escalada de privilegios: un `Miembro` intenta `POST /api/Usuarios` | `403 Forbidden` por `Roles="Admin"` | `403` | ✅ CONFORME |
| CP-S-26 | `Vuln_SEC06_UpdateUsuarioPersisteUnRolFueraDeLaListaAdminMiembro` | `Rol` validado contra la lista blanca al actualizar | `Rol` distinto de `Admin`/`Miembro` → `400` | Persiste `rol: "Susepdiistrador"` tal cual | 🟡 **SEC-06** (medios) |
| CP-S-27 | `Vuln_SEC06_AddMemberAceptaElRolIndicadoSinValidarContraLaListaAdminMiembro` | `Rol` validado en `POST /api/Hogares/{id}/miembros` | Rol fuera de lista → `400` | Persiste el rol enviado sin comprobar | 🟡 **SEC-06** (medios) |

> Los tres últimos casos completan la autorización: CP-S-25 es un control positivo y CP-S-26/27 son los que **documentan SEC-06** (mismo patrón de validación ausente que [BUG-03](../backend-tests/issues/BUG-03-categorias-sin-validacion-tipo.md) en `Categoria.Tipo`).

## D. XSS (5 casos)

| ID | Caso (test) | Qué comprueba | Esperado | Obtenido | Veredicto |
|----|-------------|---------------|----------|----------|-----------|
| CP-S-28 | `Xss_LaDescripcionYElOrigenDeUnMovimientoSeGuardanYSeDevuelvenSinTransformar` | Payload `<script>alert('xss')</script>` y `<img src=x onerror=...>` en texto libre | **No** se almacenan sin transformar (o se escapan) | Se guardan y se devuelven **idénticos** | 🟡 **SEC-05** (medios) |
| CP-S-29 | `Xss_ElSerializadorJsonDeLaApiEscapaLosCaracteresHtmlDeLosCamposDeTexto` | El serializador neutraliza `<`/`>` en la respuesta | `\u003C` en lugar de `<` | `\u003Cscript\u003E` | ✅ CONFORME (capa transporte) |
| CP-S-30 | `Xss_LosTipsSeDevuelvenComoDatosJsonYElBackendNoGeneraHtml` | El backend no renderiza HTML (no hay XSS reflejado desde la API) | `OkObjectResult` con datos, sin HTML generado | Idéntico | ✅ CONFORME |
| CP-S-31 | `Xss_LosCamposDeTextoConLengthLimitanLoQueSePuedePersistirEnElPayload` | Límite de longitud en campos de texto | `Descripcion` ≤ 255 | 255 | ✅ CONFORME |
| CP-S-32 | `Vuln_SEC05_ElContenidoDeLosTipsNoTieneLimiteDeLongitudNiValidacionDeContenido` | `EducacionFinanciera.Contenido` acotado | `[StringLength]`/`[MaxLength]` presente | **Ninguna anotación** | 🟡 **SEC-05** (medios) |

**Fuera del alcance verificable aquí:** el comportamiento de render del frontend (repo `RemesaSmartSV/frontend`). Si el frontend usa `dangerouslySetInnerHTML` con `Descripcion`/`Contenido`, CP-S-28 pasa de "riesgo latente" a **XSS almacenado explotable**. Recomendado en el informe §4.

## E. Cabeceras de seguridad / Secretos / Pipeline (10 casos)

| ID | Caso (test) | Qué comprueba | Esperado | Obtenido | Veredicto |
|----|-------------|---------------|----------|----------|-----------|
| CP-S-33 | `Configuracion_LaValidacionDelJwtExigeIssuerAudienceVigenciaYClaveDeFirma` | Los 4 `Validate*` en `true` y firma HMAC-SHA256 | Todo activo | Idéntico | ✅ CONFORME |
| CP-S-34 | `Configuracion_ElAccesoADatosUsaEFCoreConConsultasParametrizadas` | Inyección SQL | Sin `FromSqlRaw`/`ExecuteSqlRaw` | Idéntico | ✅ CONFORME |
| CP-S-35 | `Vuln_SEC01_LaClaveFirmanteDelJwtEstaEnTextoPlanoEnElAppsettingsVersionado` | La clave de firma no está en el repo | Sin `Jwt:Key` real en `appsettings.json` | Clave fija `RemesaSmartSV_Clave_Dev_2026_#Segura#` en el archivo versionado | 🔴 **SEC-01** (crítica) |
| CP-S-36 | `Vuln_SEC02_LaContrasenaDePostgresEstaEnTextoPlanoEnElComposeYSeReutilizaEnLaApi` | Sin credenciales de BD en texto plano | Sin `POSTGRES_PASSWORD` literal ni reutilización | `SecretPassword123!` dos veces + puerto 5432 publicado | 🔴 **SEC-02** (crítica) |
| CP-S-37 | `Vuln_SEC03_NoHayNingunaCabeceraDeSeguridadConfiguradaEnElBackend` | `nosniff`, CSP, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, HSTS | Todas presentes | **Ninguna** | 🟠 **SEC-03** (alta) |
| CP-S-38 | `Vuln_SEC04_NoHayLimiteDePeticionesNiBloqueoDeCuentaEnElLogin` | `AddRateLimiter`/`RequireRateLimiting`/bloqueo de intentos | Presentes en login/registro | **Ninguno** | 🟠 **SEC-04** (alta) |
| CP-S-39 | `Vuln_SEC08_ElComposeArrancaLaApiEnDevelopmentExpuestoASwaggerYAlDetalleDeErrores` | Entorno de ejecución | `Production`/configurable en despliegue | `ASPNETCORE_ENVIRONMENT=Development` + `UseSwagger()` | 🟡 **SEC-08** (medios) |
| CP-S-40 | `Vuln_SEC09_ElContenedorSirveLaApiPorHttpSinTlsYLaBaseDeDatosQuedaExpuestaAlHost` | TLS en tránsito | HTTPS o terminación TLS documentada | `ASPNETCORE_URLS=http://+:8080`, `8080:8080` y `5432:5432` publicados | 🟡 **SEC-09** (medios) |
| CP-S-41 | `Vuln_SEC10_ElPipelineDeNoEscaneaSecretosYLaApiAceptaTodosLosHostHeader` | Escaneo de secretos + `dotnet test` en CI + `AllowedHosts` restringido | gitleaks/trufflehog, tests, hosts acotados | Sin escaneo, sin `dotnet test`, `AllowedHosts: "*"` | 🟢 **SEC-10** (baja) |
| CP-S-42 | `Vuln_SEC10_LaValidacionDeModeloImplicitaEstaDesactivadaEnLosControllers` | Validación de modelo activa en `[ApiController]` | Sin supresión | `SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true` | 🟢 **SEC-10** (baja) |

> Los 42 casos de §A–§E corresponden uno a uno a los 42 métodos `[Fact]` de `backend.Tests/SeguridadTests.cs`, sin repeticiones. Los tres `Configuracion_*` de arranque (CP-S-16 a CP-S-18) están agrupados en §C por tratar de CSRF/CORS/orden del pipeline, aunque su clase sea `SeguridadConfiguracionTests`.

---

## Hallazgos (issues listos para GitHub)

| ID | Hallazgo | Severidad | Casos | Issue |
|----|----------|-----------|-------|-------|
| SEC-01 | Clave de firma JWT en texto plano y versionada | 🔴 Crítica | CP-S-35 | [SEC-01](issues/SEC-01-clave-jwt-hardcodeada.md) |
| SEC-02 | Contraseña de PostgreSQL hardcodeada y reutilizada, BD expuesta al host | 🔴 Crítica | CP-S-36 | [SEC-02](issues/SEC-02-contrasena-postgres-hardcodeada.md) |
| SEC-03 | Ninguna cabecera de seguridad (ni HSTS) | 🟠 Alta | CP-S-37 | [SEC-03](issues/SEC-03-sin-cabeceras-de-seguridad.md) |
| SEC-04 | Sin rate limiting ni bloqueo de cuenta en login/registro | 🟠 Alta | CP-S-38 | [SEC-04](issues/SEC-04-sin-rate-limit-en-login.md) |
| SEC-05 | Texto libre sin sanear; `Contenido` sin límite de longitud | 🟡 Media | CP-S-28, CP-S-32 | [SEC-05](issues/SEC-05-campos-texto-sin-saneamiento.md) |
| SEC-06 | `Rol` sin lista blanca (typos rompen autorización, valores inventados) | 🟡 Media | CP-S-26, CP-S-27 | [SEC-06](issues/SEC-06-rol-sin-lista-blanca.md) |
| SEC-07 | JWT sin `jti`/revocación/refresh y `ClockSkew` por defecto | 🟡 Media | CP-S-09, CP-S-10 | [SEC-07](issues/SEC-07-jwt-sin-revocacion-ni-clock-skew.md) |
| SEC-08 | Compose en `Development`: Swagger y stack traces expuestos | 🟡 Media | CP-S-39 | [SEC-08](issues/SEC-08-aspnet-environment-development.md) |
| SEC-09 | API y BD sin TLS, puertos publicados al host | 🟡 Media | CP-S-40 | [SEC-09](issues/SEC-09-http-sin-tls-en-contenedor.md) |
| SEC-10 | Sin escaneo de secretos en CI, `AllowedHosts: "*"`, validación de modelo desactivada | 🟢 Baja | CP-S-41, CP-S-42 | [SEC-10](issues/SEC-10-higiene-de-configuracion-y-ci.md) |

**Hallazgos ya reportados en corridas anteriores que esta auditoría confirma y no duplica:** BUG-01 (claim de rol con URI largo, sin `iat` — HU-01), BUG-02 (`PUT /api/Hogares` sin restricción de rol — HU-01), BUG-03 (`Categorias.Tipo` sin validación — backend-tests).
