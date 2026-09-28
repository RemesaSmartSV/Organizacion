# Entrega — Auditoría de seguridad básica (issue #76) · RemesaSmart SV

**Responsable:** Emelie · **Rol:** QA / Auditoría de seguridad
**Alcance:** XSS · CSRF · tokens JWT · contraseñas/secrets hardcodeados · cabeceras de seguridad
**Componente:** `backend/` (ASP.NET Core Web API .NET 8 + PostgreSQL 16)
**Fecha de ejecución:** domingo 27 de septiembre de 2026
**Método:** revisión estática del código real + **42 casos automatizados** en xUnit (re-ejecutables)

---

## Resultado en una línea

> **5 áreas verificadas · 10 hallazgos (2 críticos, 2 altos, 5 medios, 1 baja) · 42/42 casos automatizados ejecutados · 0 bloqueados ⏸️**

| Hallazgo | Área | Resumen | Severidad |
|----------|------|---------|-----------|
| [SEC-01](issues/SEC-01-clave-jwt-hardcodeada.md) | Secretos | `Jwt:Key` en texto plano en `appsettings.json` versionado → se pueden firmar tokens `Admin` de cualquier hogar | 🔴 Crítica |
| [SEC-02](issues/SEC-02-contrasena-postgres-hardcodeada.md) | Secretos | Contraseña `<POSTGRES_PASSWORD>` en `docker-compose.yml`, reutilizada por la API y con `5432:5432` publicado | 🔴 Crítica |
| [SEC-03](issues/SEC-03-sin-cabeceras-de-seguridad.md) | Cabeceras | No hay ni una cabecera de seguridad (ni HSTS, ni `nosniff`, ni CSP) | 🟠 Alta |
| [SEC-04](issues/SEC-04-sin-rate-limit-en-login.md) | JWT | Login y registro sin rate limiting ni bloqueo de cuenta (contraseñas de 6 caracteres) | 🟠 Alta |
| [SEC-05](issues/SEC-05-campos-texto-sin-saneamiento.md) | XSS | Texto libre sin sanear (riesgo de XSS almacenado en el frontend) y `Contenido` sin límite de longitud | 🟡 Media |
| [SEC-06](issues/SEC-06-rol-sin-lista-blanca.md) | Autorización | `Rol` es texto libre: un typo deja al usuario sin permisos, un valor inventado crea roles fantasma | 🟡 Media |
| [SEC-07](issues/SEC-07-jwt-sin-revocacion-ni-clock-skew.md) | JWT | Sin `jti`/revocación/refresh y con `ClockSkew` de 5 min por defecto: los cambios de rol no surten efecto hasta 8 h | 🟡 Media |
| [SEC-08](issues/SEC-08-aspnet-environment-development.md) | Entorno | El compose arranca en `Development`: Swagger UI y stack traces expuestos | 🟡 Media |
| [SEC-09](issues/SEC-09-http-sin-tls-en-contenedor.md) | Transporte | API en `http://+:8080` y BD en `5432:5432` sin TLS, mientras hay `UseHttpsRedirection()` | 🟡 Media |
| [SEC-10](issues/SEC-10-higiene-de-configuracion-y-ci.md) | Pipeline | Sin escaneo de secretos ni `dotnet test` en CI, `AllowedHosts: "*"`, validación de modelo desactivada | 🟢 Baja |

**Lo que sí está bien (y quedó cubierto con pruebas):** contraseñas de usuario con PBKDF2 + sal y el hash nunca se expone; JWT con validación de firma/issuer/audience/vigencia que rechaza tokens falsificados, vencidos o de otro emisor; **CSRF no explotable** (bearer en cabecera, sin cookies, CORS con origen fijo y sin credenciales); sin SQL crudo (EF Core parametrizado); aislamiento por hogar tomado del token (sin IDOR ni mass assignment); superficie anónima mínima (4 endpoints).

## Veredicto por área solicitada

| Área | Veredicto | Detalle |
|------|-----------|---------|
| XSS | ⚠️ Riesgo latente | El backend no es sumidero (solo JSON, con `<`/`>` escapados), pero no sanea lo que persiste. Depende del render del frontend (repo aparte, no auditado). |
| CSRF | ✅ Conforme | No explotable con la arquitectura actual; los tests lo bloquean para que nadie lo introduzca con un "arreglo" de CORS. |
| Tokens JWT | ⚠️ Parcial | Validación correcta y probada; clave filtrada (SEC-01), sin revocación (SEC-07) y sin rate limit (SEC-04). |
| Contraseñas hardcodeadas | ❌ 2 críticas | Clave JWT y contraseña de BD en archivos versionados. El *hashing* de contraseñas de usuario sí es correcto. |
| Cabeceras de seguridad | ❌ Ausentes | Cero cabeceras; además el compose expone Swagger y el TLS no existe en el contenedor. |

## Qué se hizo

1. **Contrato de verificación:** los 5 puntos del issue se contrastaron contra el código real (`Program.cs`, `AuthService`, los 9 controllers, `Entities`, `appsettings.json`, `docker-compose.yml`, `Dockerfile`, `ci.yml`) antes de diseñar los casos.
2. **Automatización:** 42 casos xUnit en `backend.Tests/SeguridadTests.cs`, organizados en 5 clases (`SeguridadJwtTests`, `SeguridadContrasenasTests`, `SeguridadAutorizacionTests`, `SeguridadXssTests`, `SeguridadConfiguracionTests`). Combinan pruebas de comportamiento (tokens, hashing, autorización por reflexión, payloads XSS) con **escaneo de los archivos de configuración versionados** (secretos, cabeceras, pipeline).
3. **Documentación de hallazgos** como issues listos para pegar en GitHub, con evidencia `archivo:línea`, pasos de reproducción y corrección propuesta.
4. **Ningún cambio en el código del backend**: la auditoría no corrige, reporta. Las correcciones son PR del equipo de desarrollo.

## Contenido de esta carpeta

| Archivo | Descripción |
|---------|-------------|
| `Auditoria_Seguridad.md` | **Informe principal**: análisis por área con evidencia, CWE, impacto y plan de remediación priorizado |
| `Casos_Prueba_Seguridad.md` | Diseño de los 42 casos (CP-S-01..CP-S-42) con esperado / obtenido / veredicto |
| `issues/SEC-01..SEC-10` | Un archivo por hallazgo, listo para crear el issue en GitHub |
| `resultados_SEGURIDAD.csv` / `.json` | Resultados maquinables de la corrida (suite de seguridad + suite previa) |
| `evidencia_raw.log` | Salida real de `dotnet test` |
| `Generar_Resultados_Seguridad.ps1` | Script que ejecuta la suite y regenera CSV/JSON/log |

## Cómo reproducir la ejecución

```powershell
# 1. El proyecto de tests referencia backend\RemesaSmartSV.csproj
#    (si la carpeta backend/ está vacía, descomprimir backend-develop.zip en ella)
# 2. Suite completa: 94 casos (52 de QA previa + 42 de seguridad)
dotnet test backend.Tests\backend.Tests.csproj

# 3. Solo la auditoría de seguridad
dotnet test backend.Tests\backend.Tests.csproj --filter "FullyQualifiedName~Seguridad"

# 4. Regenerar los artefactos de esta carpeta
powershell -ExecutionPolicy Bypass -File doc\qa\SEGURIDAD\Generar_Resultados_Seguridad.ps1
```

No requiere Docker ni PostgreSQL: los casos usan EF Core InMemory, `JwtSecurityTokenHandler` y reflexión sobre el ensamblado. Para lo que sí necesita la API levantada (cuerpos de error 500, cabeceras reales, rate limit) la batería es la de HTTP con Docker (`doc/qa/HU01/Ejecutar_Pruebas_HU01.ps1` como plantilla).

## Convención importante de los tests

Las pruebas con prefijo **`Vuln_SECxx_`** **afirman que el hueco sigue existiendo**: pasan hoy y **fallarán cuando se corrija** el hallazgo. Quien corrija SEC-01, por ejemplo, debe invertir o eliminar `Vuln_SEC01_LaClaveFirmanteDelJwtEstaEnTextoPlanoEnElAppsettingsVersionado` en la misma PR: ese rojo es la señal de que el arreglo llegó al punto correcto. Las pruebas sin ese prefijo (`Jwt_...`, `Autorizacion_...`, `ContrasenaHash_...`, `Xss_...`) son controles que **deben seguir en verde**.

## Notas para el equipo

- **Prioridad 0 (rotar, no solo mover):** SEC-01 y SEC-02 exigen **rotar** los secretos, no solo sacarlos del repo. La clave JWT actual debe considerarse filtrada; rotarla invalida los tokens emitidos (efecto deseado).
- **Coordinación con frontend** (repo `RemesaSmartSV/frontend`, fuera del alcance de esta auditoría): (a) nunca renderizar `descripcion`/`contenido` como HTML, (b) CSP en el origen del frontend, (c) decidir dónde vive el token (`localStorage` amplifica el impacto de un XSS).
- **Convergencia de hallazgos:** SEC-06 es el mismo patrón que [BUG-03](../backend-tests/issues/BUG-03-categorias-sin-validacion-tipo.md) (`Categoria.Tipo` sin validar) → conviene resolver ambos con enum/mapa de dominio. SEC-07 solapa con [BUG-01](../HU01/issues/BUG-01-jwt-sin-claim-role-corto.md) (mismo método `GenerateToken`).
- **Higiene de repo:** la carpeta `backend/` con el código fuente **no debe versionarse** en este repositorio de documentación (solo los tests y la evidencia); los hallazgos se reportan contra el repo `RemesaSmartSV/backend`.
- **Limitaciones de alcance de esta corrida:** no se pudo verificar el frontend (repo `RemesaSmartSV/frontend`, Node/Vitest pendiente) ni la API en vivo (Docker Desktop no estaba activo en esta máquina). Ambos puntos están anotados en el informe como *no verificado*, nunca como conforme; las comprobaciones que los requieren quedan listadas para la batería HTTP.
