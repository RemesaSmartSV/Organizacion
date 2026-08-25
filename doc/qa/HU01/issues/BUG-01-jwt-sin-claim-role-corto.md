# BUG-01 — El JWT no incluye el claim corto `role` ni `iat`

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Auth] El JWT serializa el rol con el nombre largo de URI (`http://schemas.microsoft.com/.../claims/role`) en lugar de `role`, y omite `iat`**

## Labels sugeridos
`bug` · `backend` · `security/JWT` · `prioridad: media`

## Descripción

El token emitido por `POST /api/Auth/register` y `POST /api/Auth/login` cumple la vigencia documentada (8 h), pero **el contrato de claims documentado no se cumple**: el claim de rol no aparece como `role` sino con el nombre largo de Microsoft, y el token no incluye `iat`.

Esto afecta al **frontend**: al decodificar el payload con `jwt-decode` o similar, `payload.role` devuelve `undefined`, rompiendo cualquier lógica de UI basada en el rol (mostrar/u ocultar opciones de Admin, etc.). En el backend no rompe nada porque el middleware mapea ese claim a `ClaimTypes.Role` de forma interna.

## Evidencia (payload decodificado del token real)

```json
{
  "idUsuario": "1",
  "idHogar": "1",
  "http://schemas.microsoft.com/ws/2008/06/identity/claims/role": "Admin",
  "email": "carlos.h01@demo-test.com",
  "exp": 1787647611,
  "iss": "RemesaSmartSV",
  "aud": "RemesaSmartSVClient"
}
```

- ✅ Vigencia correcta verificada empíricamente: `exp − momento_de_emisión = 28800 s = 8 h`
- ❌ No existe claim `role`
- ❌ No existe claim `iat` (la fecha de emisión solo se puede deducir restando 8 h a `exp`)

## Pasos para reproducir

1. Levantar el entorno: `docker compose up -d --build postgres_db backend_api`
2. Ejecutar:
   ```bash
   curl -X POST http://localhost:8080/api/Auth/register \
     -H "Content-Type: application/json" \
     -d '{"nombre":"Test","correo":"test@demo.com","contrasena":"Demo1234!","nombreFamiliar":"Familia Test"}'
   ```
3. Copiar el `token` de la respuesta y decodificar su payload (parte central, base64url) en https://jwt.io
4. Observar que el claim de rol usa el URI largo y que no hay `iat`.

## Comportamiento esperado (según Casos_Prueba_HU01.md, CP-08)

```json
{
  "idUsuario": "1",
  "idHogar": "1",
  "role": "Admin",
  "email": "carlos.h01@demo-test.com",
  "iat": 1787618810,
  "exp": 1787647611
}
```

## Causa probable y corrección sugerida

**Archivo:** `Services/AuthService.cs` → método `GenerateToken` (líneas ~70–89). Se crea el claim con `new Claim(ClaimTypes.Role, usuario.Rol)` y el mapa de conversión de claims de salida de `JwtSecurityTokenHandler` no está normalizándolo a `role`.

Opciones de corrección (cualquiera):

```csharp
// Opción A — claim explícito corto
new Claim("role", usuario.Rol)

// Opción B — desactivar el mapeo automático una sola vez al inicio (Program.cs)
JwtSecurityTokenHandler.DefaultOutboundClaimTypeMap.Clear();

// Y para iat, pasar issuedAt explícito:
var token = new JwtSecurityToken(
    issuer: ..., audience: ...,
    claims: claims,
    issuedAt: DateTime.UtcNow,      // ← agrega iat
    expires: DateTime.UtcNow.AddHours(8),
    signingCredentials: ...);
```

⚠️ Nota: si se corrige, verificar el login de usuarios ya existentes y coordinar con el frontend el cambio del nombre del claim.

## Entorno verificado
- Rama `develop` · .NET 8 · `Microsoft.AspNetCore.Authentication.JwtBearer` 8.0.30
- Docker Compose local (API :8080 + PostgreSQL 16) — 2026-08-24
- Caso de prueba asociado: **CP-08**
