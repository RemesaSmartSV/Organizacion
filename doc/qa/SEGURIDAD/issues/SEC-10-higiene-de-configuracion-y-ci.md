# SEC-10 — Higiene de configuración y de CI

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Baja] CI sin escaneo de secretos ni ejecución de tests, `AllowedHosts: "*"` y validación de modelo implícita desactivada**

## Labels sugeridos
`security` · `ci` · `configuracion` · `owasp-a05` · `prioridad: baja`

## Descripción

Cuatro cosas de higiene que, por separado, son bajas, pero que hacen que **los hallazgos anteriores puedan repetirse sin que nadie se entere**:

### 1. El pipeline no escanea secretos ni ejecuta los tests

`backend/.github/workflows/ci.yml` solo hace tres pasos:
```yaml
- run: dotnet restore RemesaSmartSV.csproj
- run: dotnet build RemesaSmartSV.csproj --no-restore --configuration Release
- run: docker build -t remesasmart-backend:test .
```

- No hay `gitleaks`/`trufflehog` → un secreto nuevo (como los de SEC-01 y SEC-02) entra sin ninguna señal en el PR.
- No hay `dotnet test` → las 94 pruebas del proyecto (**incluidas las 42 de seguridad de esta auditoría**, que fallan cuando un hueco se corrige y vuelven a rojo cuando se reintroduce) **nunca se ejecutan en CI**. En la práctica, la suite depende de que alguien la corra a mano.

### 2. `AllowedHosts: "*"`

`backend/appsettings.json:8` acepta cualquier cabecera `Host`. En una API no es crítico por sí solo, pero elimina una barrera trivial frente a *host header injection*/cache poisoning y debería acotarse al dominio real.

### 3. Validación de modelo implícita desactivada

`backend/Program.cs:13`
```csharp
options.SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true
```
Con `[ApiController]`, ASP.NET normalmente trata las propiedades no-nullable sin `[Required]` como obligatorias. Al desactivarlo, un body como `{"nombre":"X"}` (sin `correo`, sin `contrasena`) pasa la validación y llega a `AuthService`, donde `PasswordHasher.HashPassword(usuario, null)` revienta en runtime con un `500` en lugar de devolver un `400` con mensaje útil. Menos grave: un `500` por entrada inválida es ruido y, con SEC-08, una página de detalle de excepciones.

## Pasos para reproducir

```powershell
# 1. CI no ejecuta los tests ni busca secretos
Select-String -Path backend\.github\workflows\ci.yml -Pattern "gitleaks|trufflehog|dotnet test"
# (sin resultados)

# 2. AllowedHosts sin acotar
(Get-Content backend\appsettings.json -Raw | ConvertFrom-Json).AllowedHosts   # "*"

# 3. Body incompleto en register -> 500 en vez de 400
curl.exe -i http://localhost:8080/api/Auth/register -Method Post -ContentType "application/json" -d '{"nombre":"SoloNombre"}'
```

## Comportamiento esperado

1. El workflow ejecuta `dotnet test` y falla el build si algún test falla (hoy hay 94).
2. Hay un paso de escaneo de secretos (gitleaks como acción de GitHub) que bloquea el merge.
3. `AllowedHosts` con los dominios reales por entorno.
4. Body incompleto → `400` con detalle de qué campo falta, no `500`.

## Causa probable y corrección sugerida

**Causa:** el CI se creó mínimo (compilar y construir la imagen) y nunca se le añadió el gate de calidad; el resto son decisiones de conveniencia de desarrollo que nadie revisó.

**Corrección:**
```yaml
# backend/.github/workflows/ci.yml
  build-and-test:
    steps:
    - uses: actions/checkout@v4
      with: { fetch-depth: 0 }
    - uses: actions/setup-dotnet@v4
      with: { dotnet-version: '8.0.x' }
    - name: Escaneo de secretos
      uses: gitleaks/gitleaks-action@v2
      env: { GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}" }
    - run: dotnet restore RemesaSmartSV.csproj
    - run: dotnet build RemesaSmartSV.csproj --no-restore --configuration Release
    - name: Tests unitarios y de seguridad
      run: dotnet test ..\backend.Tests\backend.Tests.csproj --configuration Release
    - run: docker build -t remesasmart-backend:test .
```
```jsonc
// appsettings.json -> placeholder, el dominio real va por entorno
"AllowedHosts": "localhost;127.0.0.1"   // en produccion: AllowedHosts=api.remesasmart.sv
```
```csharp
// Program.cs: activar la validacion implicita de [Required] en no-nullables
builder.Services.AddControllers();   // sin SuppressImplicitRequiredAttributeForNonNullableReferenceTypes
```
> Con la validación implícita activada hay que revisar los DTOs con `string?` opcionales (`UpdateUsuarioRequest.Nombre`, `AddMemberRequest.Rol`) para que sigan siendo opcionales de verdad, y esperar algún `400` nuevo en pruebas — es el comportamiento correcto.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC10_ElPipelineDeNoEscaneaSecretosYLaApiAceptaTodosLosHostHeader` y `Vuln_SEC10_LaValidacionDeModeloImplicitaEstaDesactivadaEnLosControllers` (fallan al corregir).
⚠️ El caso sobre `dotnet test` en el CI **pasa hoy** porque efectivamente no está: cuando se añada el paso, ese test pasará a rojo y habrá que invertirlo (es el detector del arreglo).

## Entorno verificado
- `develop` · GitHub Actions (ubuntu-latest, .NET 8)
- Revisión estática + 42 casos xUnit — 2026-09-27
- Casos: CP-S-41, CP-S-42
- Relacionado: SEC-01, SEC-02 (el escaneo de secretos es la red de seguridad de ambos)
