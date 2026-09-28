# SEC-04 — Sin rate limiting ni bloqueo de cuenta en login y registro

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Alta] `POST /api/Auth/login` y `/api/Auth/register` no tienen límite de intentos ni bloqueo de cuenta: permite fuerza bruta y abuso de creación de cuentas**

## Labels sugeridos
`security` · `auth` · `rate-limiting` · `owasp-a07` · `prioridad: alta`

## Descripción

Los dos endpoints públicos de autenticación no tienen ninguna protección frente a abuso:

`backend/Controllers/AuthController.cs:16-17` y `:26-27`
```csharp
[HttpPost("register")]
[AllowAnonymous]
...
[HttpPost("login")]
[AllowAnonymous]
```

- No hay `AddRateLimiter()` / `RequireRateLimiting` en `Program.cs`.
- `AuthService` no registra intentos fallidos ni bloquea cuentas (no hay campo ni lógica de bloqueo; `LoginAsync` solo devuelve `null`).
- La política de contraseña es `MinLength(6)` (`DTOs/AuthDtos.cs:6`), es decir, el espacio de búsqueda de la fuerza bruta es pequeño (≈10⁶ para 6 dígitos) y las contraseñas de usuario son elegidas por el usuario final, no por el sistema.

Combinado con SEC-01 (clave de firma conocida), el impacto del login sin rate limit es menor —un atacante ya puede fabricar tokens—, pero **mientras SEC-01 siga abierto este control es la mitigación complementaria** y no puede obviarse: cada login válido genera un token de 8 h que es un activo robable.

Además, `register` sin límite permite **creación masiva de hogares** (y por tanto de filas en 8 tablas y migraciones) — vector típico de abuso de recursos y de spam de datos.

## Pasos para reproducir

```powershell
# Sin límite de intentos: 60 intentos en segundos, ninguno bloqueado
1..60 | ForEach-Object {
  $cuerpo = @{ correo = "admin@demo-test.com"; contrasena = "incorrecta$_" } | ConvertTo-Json
  $r = Invoke-WebRequest -Uri http://localhost:8080/api/Auth/login -Method Post `
        -ContentType "application/json" -Body $cuerpo -SkipHttpErrorCheck
  "{0} -> {1}" -f $_, $r.StatusCode      # 60 x 401
}
```

```powershell
# Sin límite de registros: 30 hogares creados en segundos
1..30 | ForEach-Object {
  $cuerpo = @{ nombre="Bot$_"; correo="bot$_@spam.test"; contrasena="123456"; nombreFamiliar="Spam $_" } | ConvertTo-Json
  (Invoke-WebRequest -Uri http://localhost:8080/api/Auth/register -Method Post `
     -ContentType "application/json" -Body $cuerpo -SkipHttpErrorCheck).StatusCode   # 30 x 200
}
```

## Comportamiento esperado

1. Tras N intentos fallidos (p. ej. 5) para el mismo correo: bloqueo temporal (15 min) o, como mínimo, respuesta con `Retry-After`.
2. Límite de peticiones por IP en `/api/Auth/login` y `/api/Auth/register` (p. ej. 5/min y 3/hora respectivamente) → `429` con `Retry-After`.
3. `register` devuelve `201`/`200` pero no crea nada cuando se supera el límite.

## Causa probable y corrección sugerida

**Causa:** no se contempló el abuso de la capa de autenticación; el proyecto no incluye `Microsoft.AspNetCore.RateLimiting` (ni el paquete ni los `[EnableRateLimiting]`).

**Corrección (dos capas, .NET 8):**
```csharp
// Program.cs
builder.Services.AddRateLimiter(opt =>
{
    opt.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    opt.AddPolicy("auth", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "desconocido",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 5,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
            AutoReplenishment = true
        }));
});
```
```csharp
// AuthController.cs
[EnableRateLimiting("auth")]
[HttpPost("login")]
[AllowAnonymous]
public async Task<ActionResult<LoginResponse>> Login(...) { ... }
```
Y para el bloqueo por cuenta, añadir a `Usuario` los campos `IntentosFallidos` / `BloqueadoHasta`, incrementarlos en `LoginAsync` y devolver `423 Locked`/`429` tras 5 fallos (restableciendo el contador al iniciar sesión). Para `register`, un límite por IP de 3 por hora basta.

Considerar además (no bloqueante para este issue): notificar al usuario por correo tras N intentos fallidos, como en la OWASP Authentication Cheat Sheet.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC04_NoHayLimiteDePeticionesNiBloqueoDeCuentaEnElLogin` (falla cuando se corrige). El bloqueo por cuenta, al requerir migraciones y reloj, queda fuera de xUnit y se debe probar con la batería HTTP (patrón de `doc/qa/HU01/Ejecutar_Pruebas_HU01.ps1`).

## Entorno verificado
- `develop` · API .NET 8 + PostgreSQL 16 (compose)
- Revisión estática + 42 casos xUnit — 2026-09-27
- Caso: CP-S-38
- Relacionado: SEC-01 (si la clave está filtrada, el login deja de ser la vía principal de entrada), SEC-07 (tokens de 8 h sin revocación)
