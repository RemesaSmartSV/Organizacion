# Auditoría de Seguridad Básica — RemesaSmart SV (backend)

**Issue:** [#76 — Auditoría de seguridad básica](https://github.com/RemesaSmartSV/Organizacion/issues/76)
**Alcance:** verificación de **XSS**, **CSRF**, **tokens JWT**, **contraseñas/secrets hardcodeados** y **cabeceras de seguridad**
**Componente:** `backend/` (ASP.NET Core Web API .NET 8 + PostgreSQL 16)
**Fecha:** domingo 27 de septiembre de 2026
**Método:** revisión estática del código real (rama `develop`, snapshot `backend-develop.zip`) + 42 casos automatizados en xUnit (`backend.Tests/SeguridadTests.cs`), 42/42 conformes a lo esperado (ver [README.md](README.md) para el conteo por área)

---

## 1. Resumen ejecutivo

| # | Hallazgo | Área | Severidad | CWE | Issue |
|---|----------|------|-----------|-----|-------|
| SEC-01 | Clave de firma JWT en texto plano y versionada en `appsettings.json` | Secretos | 🔴 Crítica | CWE-798 | [issue](issues/SEC-01-clave-jwt-hardcodeada.md) |
| SEC-02 | Contraseña de PostgreSQL `SecretPassword123!` en `docker-compose.yml`, reutilizada por la API y con el puerto 5432 publicado | Secretos | 🔴 Crítica | CWE-798 | [issue](issues/SEC-02-contrasena-postgres-hardcodeada.md) |
| SEC-03 | Ninguna cabecera de seguridad configurada (sin `nosniff`, CSP, `X-Frame-Options`, `Referrer-Policy`, HSTS) | Cabeceras | 🟠 Alta | CWE-693 | [issue](issues/SEC-03-sin-cabeceras-de-seguridad.md) |
| SEC-04 | Sin rate limiting ni bloqueo de cuenta en login/registro | Tokens JWT | 🟠 Alta | CWE-307 | [issue](issues/SEC-04-sin-rate-limit-en-login.md) |
| SEC-05 | `EducacionFinanciera.Contenido` sin límite de longitud ni validación de contenido; el resto de campos de texto se persisten y se devuelven sin transformar | XSS | 🟡 Media | CWE-20 / CWE-79 | [issue](issues/SEC-05-campos-texto-sin-saneamiento.md) |
| SEC-06 | `Rol` es texto libre en `AddMemberRequest`/`UpdateUsuarioRequest` sin lista blanca | Autorización | 🟡 Media | CWE-20 | [issue](issues/SEC-06-rol-sin-lista-blanca.md) |
| SEC-07 | JWT de 8 h sin `jti`, sin refresh ni revocación; `ClockSkew` por defecto (5 min) sin fijar | Tokens JWT | 🟡 Media | CWE-613 | [issue](issues/SEC-07-jwt-sin-revocacion-ni-clock-skew.md) |
| SEC-08 | El compose arranca la API en `Development`: expone Swagger UI y la página de detalle de excepciones | Configuración / Entorno | 🟡 Media | CWE-209 | [issue](issues/SEC-08-aspnet-environment-development.md) |
| SEC-09 | El contenedor sirve la API por HTTP sin TLS mientras hay `UseHttpsRedirection()`; la base de datos queda expuesta al host | Transporte / TLS | 🟡 Media | CWE-319 | [issue](issues/SEC-09-http-sin-tls-en-contenedor.md) |
| SEC-10 | Sin escaneo de secretos en CI, `AllowedHosts: "*"`, validación de modelo implícita desactivada | Configuración / Pipeline | 🟢 Baja | CWE-693 | [issue](issues/SEC-10-higiene-de-configuracion-y-ci.md) |

**Veredicto por área solicitada:**

| Área | Veredicto | Comentario |
|------|-----------|------------|
| XSS | ⚠️ **Riesgo latente (SEC-05)** | El backend no es el sumidero (solo emite JSON y escapa `<`, `>`, `&`), pero persiste y devuelve texto libre sin sanear; el riesgo se materializa si el frontend lo renderiza como HTML. |
| CSRF | ✅ **No explotable** | Autenticación por `Authorization: Bearer` (sin cookies, sin `AllowCredentials`, sin antiforgery): un sitio tercero no puede provocar una petición autenticada. Documentado en §3. |
| Tokens JWT | ⚠️ **Parcial** | Validación de firma/issuer/audience/vigencia correcta y probada; pero la clave está hardcodeada (SEC-01), no hay revocación (SEC-07) ni rate limiting (SEC-04). |
| Contraseñas hardcodeadas | ❌ **2 críticas** | JWT key versionada (SEC-01) y contraseña de BD en el compose (SEC-02). El *hashing* de contraseñas de usuario sí es correcto (PBKDF2 + sal, nunca se expone el hash). |
| Cabeceras de seguridad | ❌ **Ausentes** | No hay un solo header de seguridad en el pipeline (SEC-03), sin HSTS y con el compose en modo `Development` (SEC-08). |

---

## 2. Tokens JWT

**Dónde:** `Services/AuthService.cs` (emisión, líneas 70–89) y `Program.cs` (validación, líneas 44–59).

### Lo que está bien (verificado con pruebas)

| Control | Estado | Evidencia |
|---------|--------|-----------|
| Algoritmo | ✅ HMAC-SHA256 con `SymmetricSecurityKey` | `AuthService.cs:86` |
| `ValidateIssuerSigningKey` | ✅ activo | `Program.cs:54` |
| `ValidateIssuer` / `ValidateAudience` | ✅ activos con `iss`/`aud` fijos | `Program.cs:51-52,55-56` |
| `ValidateLifetime` | ✅ activo | `Program.cs:53` |
| Claims mínimos | ✅ `idUsuario`, `idHogar`, rol, email | `AuthService.cs:73-79` |
| Vigencia | ✅ 8 h, sin excederse | `AuthService.cs:85` + `Jwt_LaVigenciaEsDeOchoHorasYNoMas` |
| Rechazo de token falsificado | ✅ firma con otra clave → `SecurityTokenException` | `Jwt_FirmadoConUnaClaveDistintaEsRechazadoComoTokenFalsificado` |
| Rechazo de `iss`/`aud`/vencimiento incorrectos | ✅ | `Jwt_ConIssuerDistintoEsRechazado`, `Jwt_ConAudienceDistintaEsRechazado`, `Jwt_VencidoEsRechazado` |
| Clave ausente en configuración | ✅ la app no arranca (`InvalidOperationException`) | `Program.cs:44-45` |

### Lo que falta

- **SEC-01 — la clave que valida todo lo anterior está en el repo.** `appsettings.json:15` fija `Jwt:Key = RemesaSmartSV_Clave_Dev_2026_#Segura#`. Cualquiera con lectura del repositorio puede **firmar un token con `Rol=Admin` e `idHogar` arbitrario** y acceder a los datos de cualquier hogar. La validación de firma solo protege frente a quien *no* conoce la clave. Mitigación: `dotnet user-secrets set "Jwt:Key" ...` o variable de entorno `Jwt__Key`, con placeholder no secreto en el archivo versionado; y **rotar** la clave (invalida los tokens emitidos, que es deseable).
- **SEC-04 — sin limitación de intentos.** `AuthController.Login` (`:26-27`) es público y no hay `AddRateLimiter`, ni contador de intentos fallidos, ni bloqueo de cuenta. Permite fuerza bruta y relleno de credenciales sobre contraseñas de 6 caracteres (`AuthDtos.cs:6`).
- **SEC-07 — sin revocación.** No hay claim `jti` ni lista de revocación: un token robado sirve hasta 8 h. Tampoco hay refresh token, ni `ClockSkew = TimeSpan.Zero` explícito, por lo que un token vencido hace < 5 min **todavía se acepta** (`Vuln_SEC07_UnTokenVencidoHaceMenosDeCincoMinutos...`). Consecuencia funcional: cambiar el rol de un usuario o su contraseña no surte efecto hasta que expire su token.
- **Nota menor (fuera de alcance de este issue):** el claim de rol se serializa con el URI largo de Microsoft en lugar de `role`, y falta `iat`. Ya reportado en [BUG-01 de HU-01](../HU01/issues/BUG-01-jwt-sin-claim-role-corto.md); no se vuelve a reportar aquí.
- **Contraseñas de usuario:** hashing correcto (`PasswordHasher<Usuario>` = PBKDF2-HMAC-SHA256 con sal aleatoria). Verificado: hash distinto para la misma contraseña, prefijo `AQ`, la clave nunca aparece en el hash y `ContrasenaHash` está marcado `[JsonIgnore]` (`Entities/Usuario.cs:26-27`), por lo que **no se filtra en ninguna respuesta JSON** (probado sobre el `Usuario` y el `LoginResponse` reales).

---

## 3. CSRF

**Veredicto: no explotable en la arquitectura actual.** Evidencia y razonamiento:

| Control | Estado | Evidencia |
|---------|--------|-----------|
| El token viaja en la cabecera `Authorization`, no en cookies | ✅ | `Program.cs:46-59` (`AddJwtBearer`) |
| Sin autenticación por cookies ni sesiones | ✅ | no hay `AddCookie`/`UseSession` en `Program.cs` ni en el `.csproj` (`Configuracion_LaApiUsaBearerYNoCookies...`) |
| Sin antiforgery | ✅ coherente con lo anterior | no hay `AddAntiforgery`/`UseAntiforgery` |
| CORS con origen explícito, sin wildcard y sin credenciales | ✅ | `Program.cs:62-66` (`WithOrigins("http://localhost:5173")`, sin `AllowAnyOrigin`, sin `AllowCredentials`) |
| Pipeline ordenado correctamente | ✅ | `UseAuthentication` → `UseAuthorization` → `MapControllers` (`Program.cs:86-88`) |

Razón: CSRF explota la **adjunción automática** de credenciales por el navegador. Como el navegador no adjunta el `Authorization: Bearer <token>` por sí solo, un formulario o `fetch` desde `evil.com` llega sin token y la API responde `401`. Un `<img>`/formulario tampoco puede leer la respuesta por CORS.

**Riesgo residual a vigilar (no es un bug actual):**
1. Si alguien "arregla" el CORS de producción con `AllowAnyOrigin` + `AllowCredentials` (o `SetIsOriginAllowed(_ => true)`) para "hacer que el frontend funcione", se reintroduce CSRF. La prueba `Configuracion_CorsSoloPermiteElOrigenDelFrontendSinWildcardNiCredenciales` lo bloquea.
2. Si el frontend guarda el token en `localStorage` (lo habitual con JWT), un XSS en el frontend pasa a ser robo de token → por eso SEC-05 (XSS) y SEC-01 (clave conocida) se encadenan: una clave conocida permite saltarse por completo cualquier protección del lado del navegador.
3. El origen permitido está fijado a `http://localhost:5173` en código: en un entorno staging hay que cambiarlo, y si se olvida la API simplemente no acepta el frontend (fallo ruidoso, no silencioso).

---

## 4. XSS

**Veredicto: el backend no es el sumidero, pero el proyecto no tiene defensa en profundidad.** No hay renderizado HTML en la API (no sirve SPA ni plantillas, `AddControllers` + `MapControllers`), por lo que **no hay XSS reflejado ni almacenado ejecutable desde la API**.

| Control | Estado | Evidencia |
|---------|--------|-----------|
| Sin HTML generado por el servidor | ✅ | no hay vistas/Razor/SPA en el proyecto |
| El serializador JSON escapa `<`, `>`, `&` | ✅ mitigación de transporte | `Xss_ElSerializadorJsonDeLaApiEscapaLosCaracteresHtmlDeLosCamposDeTexto` (verifica `\u003C`) |
| Respuestas de tips como datos, no como HTML | ✅ | `Xss_LosTipsSeDevuelvenComoDatosJsonYElBackendNoGeneraHtml` |
| Límite de longitud en la mayoría de campos de texto | ✅ parcial | `Movimiento.Descripcion` 255 (`Xss_LosCamposDeTextoConLength...`) |
| **Saneamiento/escape de contenido** | ❌ | `Xss_LaDescripcionYElOrigen...` prueba que `<script>alert('xss')</script>` y `<img src=x onerror=alert(1)>` se **guardan y se devuelven tal cual** |
| **Longitud de `EducacionFinanciera.Contenido`** | ❌ sin límite | `Entities/EducacionFinanciera.cs:20` sin `[StringLength]`/`[MaxLength]` (a diferencia de los otros campos de texto) → se puede guardar contenido arbitrariamente largo (abuso de almacenamiento/DoS suave) |

**Dónde queda el riesgo:** los campos `Descripcion`, `OrigenEmisora`, `Categoria.Nombre`, `MetaAhorro.Titulo`, `Usuario.Nombre`, `Hogar.NombreFamiliar` y `EducacionFinanciera.Contenido` aceptan HTML/JS sin filtrar. Si el frontend los pinta con `dangerouslySetInnerHTML`, `innerHTML` o Markdown sin escapar → **XSS almacenado** con impacto real: el token del victimizado queda en manos del atacante (el token se manda en cada request autenticado).

**Corrección recomendada (capa 1, la importante):** en el frontend, renderizar siempre como texto (`React` escapa por defecto; nunca usar `dangerouslySetInnerHTML` con datos de usuario) y añadir una **CSP** en el frontend que prohíba `script-src 'self'`/`'unsafe-inline'`.
**Capa 2 (defensa en profundidad, este repo):** `Helmet` no aplica a la API, pero sí conviene (a) `[StringLength]` en `Contenido`, (b) sanitizar/permitir solo un subconjunto de etiquetas si el contenido es HTML rico deliberado, y (c) documentar en el README del backend qué campos son texto plano por contrato.

**No verificado en esta auditoría:** el frontend vive en otro repositorio (`RemesaSmartSV/frontend`), así que el comportamiento de render no pudo probarse aquí. Queda como recomendación explícita para el equipo de frontend (y es el mismo repo que ya tiene pendientes los tests de Vitest).

---

## 5. Contraseñas y secrets hardcodeados

| Secreto | Dónde | Estado |
|---------|-------|--------|
| `Jwt:Key` = `RemesaSmartSV_Clave_Dev_2026_#Segura#` | `appsettings.json:15` (archivo **versionado**) | 🔴 **SEC-01** |
| `POSTGRES_PASSWORD: SecretPassword123!` | `docker-compose.yml:12` (versionado) | 🔴 **SEC-02** |
| `Password=SecretPassword123!` en la cadena de conexión del servicio `backend_api` | `docker-compose.yml:31` (misma clave reutilizada) | 🔴 **SEC-02** |
| `"Password="` (vacío) en la cadena de conexión de `appsettings.json:10` | placeholder | 🟡 Si se despliega sin *user-secrets*, la app intenta conectar **sin contraseña** en lugar de fallar (falla ruidosa solo si Postgres la exige). |
| `AllowedHosts: "*"` | `appsettings.json:8` | 🟢 SEC-10 |
| Contraseñas de ejemplo `Clave12345` | `backend/RemesaSmartSV.http`, README | 🟢 solo desarrollo, sin valor real |
| Clave de pruebas `clave-de-prueba-...` | `backend.Tests/SeguridadTests.cs` | 🟢 fixture de test |

Puntos de riesgo concretos:

1. **`docker-compose.yml` no usa variables de entorno para secretos.** Cualquiera que clone el repo conoce la contraseña de la BD; y como el puerto `5432:5432` está publicado, esa contraseña sirve para entrar **desde el host** a la base de datos del entorno levantado por el compose (con datos reales de usuarios si se reutiliza el mismo compose fuera de local).
2. **El compose no inyecta `Jwt__Key`**, así que el contenedor usa la clave del `appsettings.json` versionado (SEC-01). Aunque se arreglara `appsettings.json`, el compose seguiría arrancando la API **sin clave** y la app caería en el `InvalidOperationException` de `Program.cs:44-45` → bueno (falla ruidoso), pero conviene documentarlo.
3. **No hay escaneo de secretos en CI.** `.github/workflows/ci.yml` solo hace `restore`, `build` y `docker build`; no hay `gitleaks`/`trufflehog` ni siquiera `dotnet test` (probado en `Vuln_SEC10_ElPipelineDeNoEscaneaSecretos...`). Un secreto nuevo no se detecta en el PR.
4. **`.gitignore` ya protege `secrets.json`**, pero `appsettings.json` está versionado a propósito (es configuración base) → la solución correcta es *placeholder + sobreescritura por entorno*, no ignorar el archivo.

Corrección recomendada:
```bash
# appsettings.json -> dejar solo el placeholder
#   "Key": ""   (o "CAMBIAR_EN_CADA_ENTORNO")

# Por entorno (user-secrets en local / variables en CI y Docker)
dotnet user-secrets set "Jwt:Key" "$(openssl rand -base64 48)"
# docker-compose:  Jwt__Key=${JWT_KEY}   con .env local NO versionado
#                  POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
```
Y añadir `gitleaks` al workflow para que un secreto no vuelva a entrar.

---

## 6. Cabeceras de seguridad

**Estado: no existe ni una sola cabecera de seguridad.** El pipeline completo es (`Program.cs:78-88`):

```csharp
if (app.Environment.IsDevelopment()) { app.UseSwagger(); app.UseSwaggerUI(); }
app.UseHttpsRedirection();
app.UseCors("Frontend");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
```

| Cabecera | Estado | Riesgo |
|----------|--------|--------|
| `X-Content-Type-Options: nosniff` | ❌ ausente | El navegador puede interpretar respuestas de la API como HTML/script en un escenario de sniffing de contenido (relevante junto con SEC-05). |
| `X-Frame-Options` / `frame-ancestors` | ❌ ausente | La API puede embeberse en un `<iframe>` (clickjacking si algún flujo vuelve a renderizar respuestas en el navegador). |
| `Content-Security-Policy` | ❌ ausente | Sin defensa frente a XSS: nada impide `script-src 'unsafe-inline'` en el origen que renderice los datos. |
| `Referrer-Policy` | ❌ ausente | Fuga de URLs de la API (con `idHogar`/`idCategoria` en la ruta) a terceros. |
| `Strict-Transport-Security` (HSTS) | ❌ ausente | Sin pineo de HTTPS: la primera visita puede sufrir *downgrade* a HTTP. `UseHttpsRedirection()` (`:84`) redirige pero no obliga. |
| `Permissions-Policy` | ❌ ausente | Sin restricción de APIs de navegador. |
| `Cache-Control` en respuestas con datos financieros | ❌ ausente | El `Authorization` no se cachea, pero los JSON con datos de remesas pueden quedar en cachés intermedias. |

Además:
- **SEC-08:** `docker-compose.yml:30` fija `ASPNETCORE_ENVIRONMENT=Development`, lo que activa **Swagger UI** (`Program.cs:78-82`) y la página de detalle de excepciones de ASP.NET (stack traces, rutas, connection strings) en cualquier despliegue que reutilice ese compose. Con `SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true` (`:13`) los errores de validación además son silenciosos: un body inválido puede llegar a la lógica de negocio en vez de devolver `400`.
- **SEC-09:** el contenedor sirve por `http://+:8080` (`Dockerfile:19`) con el puerto publicado (`:33`), y `UseHttpsRedirection()` no tiene destino HTTPS configurado en ese escenario (avisa y deja pasar). El JWT viaja en claro por la red del compose.
- **SEC-10:** `AllowedHosts: "*"` acepta cualquier `Host` (no es crítico en una API, pero elimina una barrera trivial contra *host header injection*).

Corrección recomendada (mínima, en `Program.cs` antes de `UseRouting`):
```csharp
app.Use(async (ctx, next) =>
{
    var h = ctx.Response.Headers;
    h["X-Content-Type-Options"] = "nosniff";
    h["X-Frame-Options"] = "DENY";
    h["Referrer-Policy"] = "no-referrer";
    h["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()";
    h["Cache-Control"] = "no-store";
    if (!ctx.Request.IsDevelopment()) h["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
    await next();
});
```
(o `app.UseHsts()` + `app.UseHttpsRedirection()` cuando exista dominio real). La CSP se pone en el frontend, no aquí: la API no sirve HTML.

---

## 7. Verificaciones adicionales (fuera de los 5 puntos pedidos, realizadas por completitud)

| Verificación | Resultado |
|--------------|-----------|
| **Inyección SQL** | ✅ No hay SQL crudo: todo pasa por LINQ de EF Core (`Configuracion_ElAccesoADatosUsaEFCoreConConsultasParametrizadas` comprueba que no existen `FromSqlRaw`/`ExecuteSqlRaw`). |
| **IDOR / aislamiento por hogar** | ✅ Todas las consultas filtran por `idHogar` **del token**, no del cuerpo; los endpoints de creación sobrescriben `IdHogar`/`IdUsuario` (`Autorizacion_ElHogarYElUsuario...`, `Autorizacion_UnaCategoriaNoPuedeCrearseEnElHogarDeOtroUsuario...`). Coincide con lo ya verificado en las suites HU-01/HU-05. |
| **Endpoints anónimos** | ✅ Solo los 4 previstos: `AuthController.Register/Login` y `TipsFinancierosController.GetTips/GetTip` (`Autorizacion_LosEndpointsPublicosSonSoloLosDelLoginYRegistroYLosTipsDeLectura`). |
| **Autorización por rol** | ✅ `AddMember`, `Update`/`Delete` de usuarios, escritura de tips y `DELETE /api/Hogares` exigen `Admin`. ⚠️ `PUT /api/Hogares` sigue sin restricción de rol → ya reportado en [BUG-02 de HU-01](../HU01/issues/BUG-02-put-hogares-sin-restriccion-rol.md), no se duplica. |
| **Mass assignment** | ✅ `IdHogar`/`IdUsuario`/`IdMeta` se fijan desde el token/servidor en los POST; no hay campo de rol ni de propietario en las entidades de negocio. ⚠️ `MetasAhorroController.Update` permite sobrescribir `Estado` (regla de negocio, no seguridad). |
| **Enumeración de usuarios** | ✅ El login devuelve `401` genérico ("Credenciales incorrectas") tanto si el correo no existe como si la contraseña falla → no revela qué correos están registrados. |
| **Fuga de hashes** | ✅ `ContrasenaHash` con `[JsonIgnore]`; comprobado serializando el `Usuario` real. |
| **Migraciones al arrancar** | ℹ️ `db.Database.Migrate()` en `Program.cs:71-75` es operacional, no de seguridad, pero implica que la API aplica esquema con los permisos del usuario de la BD. |

---

## 8. Plan de remediación sugerido

| Prioridad | Acción | Hallazgos | Esfuerzo |
|-----------|--------|-----------|----------|
| P0 (ya) | Sacar `Jwt:Key` del repo (user-secrets/variable de entorno) y **rotar** la clave | SEC-01 | ~15 min |
| P0 (ya) | Sustituir las contraseñas del compose por `${POSTGRES_PASSWORD}` desde un `.env` no versionado; quitar el mapeo `5432:5432` si no es necesario | SEC-02, SEC-09 | ~20 min |
| P1 (sprint actual) | Middleware de cabeceras de seguridad + `Cache-Control: no-store` | SEC-03 | ~30 min |
| P1 | `AddRateLimiter` (fixed window 5/min por IP) en `login` y `register` + contador de intentos fallidos con bloqueo temporal | SEC-04 | ~1 h |
| P1 | `ClockSkew = TimeSpan.Zero`, `Jwt:Key` por entorno, claim `jti` + lista de revocación o, en su defecto, refresh token y vida más corta | SEC-07 | ~4 h |
| P2 | Lista blanca de `Rol` (`Admin`/`Miembro`) + `[StringLength]` en `EducacionFinanciera.Contenido` + nota de "texto plano por contrato" | SEC-05, SEC-06 | ~1 h |
| P2 | Compose con `ASPNETCORE_ENVIRONMENT=Production` + `ASPNETCORE_HTTPS_PORTS`/terminación TLS, o documentar que el TLS lo pone el proxy | SEC-08, SEC-09 | ~1 h |
| P2 | `gitleaks` + `dotnet test` en CI; `AllowedHosts` restringido; revisar `SuppressImplicitRequiredAttribute...` | SEC-10 | ~45 min |
| coordinated | Frontend: nunca `dangerouslySetInnerHTML`, CSP en el origen del frontend, token en `localStorage` solo si es inevitable (ideal: cookie `HttpOnly` + CSRF token si se migra) | SEC-05 | equipo frontend |
