# SEC-07 — El JWT no se puede revocar y la ventana de sesión es de 8 horas

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Media] Los JWT no tienen `jti` ni revocación (ni refresh token) y `ClockSkew` no está fijado: un token robado sirve 8 h y los cambios de rol/contraseña no surten efecto hasta expirar**

## Labels sugeridos
`security` · `jwt` · `sesiones` · `owasp-a07` · `prioridad: media`

## Descripción

La emisión del token (`backend/Services/AuthService.cs:70-89`) cumple lo esencial —HMAC-SHA256, `iss`/`aud` fijos, vigencia de 8 h, claims mínimos— pero el modelo de sesión tiene tres carencias:

1. **No hay `jti` (JWT ID).** El payload es:
   ```json
   { "idUsuario":"1", "idHogar":"1", "http://schemas.microsoft.com/ws/2008/06/identity/claims/role":"Admin",
     "email":"...","exp":...,"iss":"RemesaSmartSV","aud":"RemesaSmartSVClient" }
   ```
   Sin identificador único por token no hay forma de revocar **uno** concreto: ni lista negra, ni logout en el servidor. (Verificado en `Jwt_NoIncluyeClaimJtiPorLoQueNoSePuedeRevocarUnTokenIndividualmente`.)

2. **No hay refresh token ni vida corta.** Un token robado (XSS, equipo compartido, cabecera `Authorization` en un log, caché del navegador) es válido **8 horas** sin posibilidad de invalidarlo. Y al no haber refresh, tampoco se puede aplicar la técnica habitual de "access token corto (15 min) + refresh token revocable".

3. **`ClockSkew` no se fija** en `Program.cs:49-58`, así que aplica el valor por defecto de la librería (**5 minutos**): un token expirado hace menos de 5 min **se sigue aceptando**. Verificado en `Vuln_SEC07_UnTokenVencidoHaceMenosDeCincoMinutos...`.

**Consecuencia funcional directa (no solo teórica):** cambiar el rol de un usuario (de Admin a Miembro) o eliminar su cuenta **no surte efecto** hasta que expiren sus tokens vigentes: el usuario conserva sus permisos hasta 8 h. No hay ningún endpoint `logout` en la API.

## Pasos para reproducir

```powershell
# 1. Login y guardar el token
$token = (Invoke-RestMethod http://localhost:8080/api/Auth/login -Method Post -ContentType "application/json" -Body '{"correo":"carlos@demo-test.com","contrasena":"Demo1234!"}').token

# 2. El Admin degrada al usuario id 2 a Miembro
Invoke-RestMethod http://localhost:8080/api/Usuarios/2 -Method Put -Headers @{Authorization="Bearer $token"} -ContentType "application/json" -Body '{"rol":"Miembro"}'

# 3. El token del usuario degradado SIGUE pudiendo hacer acciones de Admin
$tokenViejo = (Invoke-RestMethod http://localhost:8080/api/Auth/login -Method Post -ContentType "application/json" -Body '{"correo":"luis@demo-test.com","contrasena":"Demo1234!"}').token
Invoke-RestMethod http://localhost:8080/api/Usuarios -Method Post -Headers @{Authorization="Bearer $tokenViejo"} -ContentType "application/json" -Body '{"nombre":"Intruso","correo":"intruso@demo-test.com","contrasena":"Demo1234!"}'
# 201 Created: el token emitido antes del cambio sigue autorizado
```

Para el `ClockSkew`, con un token fabricado (ver SEC-01 para el script de firma) cuyo `exp` sea hace 2 minutos: la API **lo acepta**; con `exp` de hace 6 minutos, lo rechaza.

## Comportamiento esperado

1. `POST /api/Auth/logout` invalida el token entregado (lista de `jti` revocados o denylist con caducidad corta).
2. Cambiar el rol o eliminar un usuario invalida sus tokens activos en el plazo de un minuto.
3. Access token de vida corta (15-30 min) + refresh token revocable, o bien vida de 8 h pero con revocación funcional.
4. `ClockSkew = TimeSpan.Zero` explícito (o documentar la tolerancia de 5 min).

## Causa probable y corrección sugerida

**Causa:** el token se diseñó para el MVP (login → 8 h) sin modelo de invalidación, y los parámetros de validación se dejaron en sus valores por defecto.

**Corrección (mínimo viable, mismo día):**
```csharp
// Program.cs
options.TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuer = true,
    ValidateAudience = true,
    ValidateLifetime = true,
    ValidateIssuerSigningKey = true,
    ValidIssuer = builder.Configuration["Jwt:Issuer"],
    ValidAudience = builder.Configuration["Jwt:Audience"],
    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
    ClockSkew = TimeSpan.Zero                     // explicito
};
```
```csharp
// Services/AuthService.cs -> token identificable
var claims = new[]
{
    new Claim("jti", Guid.NewGuid().ToString()),
    new Claim("idUsuario", usuario.IdUsuario.ToString()),
    new Claim("idHogar", usuario.IdHogar.ToString()),
    new Claim(ClaimTypes.Role, usuario.Rol),
    new Claim(JwtRegisteredClaimNames.Email, usuario.Correo)
};
```
```csharp
// Revocacion en memoria (una instancia) o Redis (varias instancias)
builder.Services.AddSingleton<ITokenRevocador, TokenRevocadorEnMemoria>();
// POST /api/Auth/logout -> revoca el jti del token recibido (cachear hasta su exp)
// Cambio de rol o baja de usuario -> revocar los tokens de ese idUsuario
await _revocador.RevocarUsuario(usuario.IdUsuario);
```
Esquema recomendado a medio plazo: access token de 15-30 min + refresh token de 7-30 días almacenado **hasheado** en BD por dispositivo, con rotación y revocación.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs`:
- `Vuln_SEC07_UnTokenVencidoHaceMenosDeCincoMinutosTodaviaSeAceptaPorElClockSkewPorDefecto` (falla al corregir)
- `Jwt_NoIncluyeClaimJtiPorLoQueNoSePuedeRevocarUnTokenIndividualmente` (falla al corregir)
- Positivos a conservar: `Jwt_VencidoEsRechazado` y `Jwt_LaVigenciaEsDeOchoHorasYNoMas` (si la vida pasa a 30 min hay que **actualizar este caso y el `README.md` del backend**, que documenta 8 h).

## Entorno verificado
- `develop` · `Microsoft.AspNetCore.Authentication.JwtBearer` 8.0.30
- Revisión estática + 42 casos xUnit — 2026-09-27
- Casos: CP-S-09, CP-S-10
- Relacionado: SEC-01 (si la clave se filtra, la revocación por lista negra pierde valor: hay que rotar clave), BUG-01 (claim de rol e `iat` ausentes, HU-01)
