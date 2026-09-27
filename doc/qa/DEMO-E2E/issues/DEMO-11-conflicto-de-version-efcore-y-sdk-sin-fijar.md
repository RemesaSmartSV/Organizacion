# DEMO-11 — Conflicto de versión de EF Core y SDK local sin fijar

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Toolchain] El build resuelve `EF Core.Relational` 8.0.11 contra los 8.0.30 declarados, y no hay `global.json`: el SDK local (10.0.302) no es el documentado (8.0.x)**

## Labels sugeridos
`chore` · `toolchain` · `dependencias` · `prioridad: baja`

## Descripción

Al correr la batería de pruebas completa que el checklist de la demo pide tener en verde
(`dotnet test` → **94/94, correcto**), aparecen dos advertencias de build que indican que el entorno de
compilación local no es el que dice la documentación.

**1. Conflicto de `Microsoft.EntityFrameworkCore.Relational` (MSB3277)** — el backend declara EF Core 8.0.30,
pero `Npgsql.EntityFrameworkCore.PostgreSQL` 8.0.11 arrastra `Relational` 8.0.11, y MSBuild elige la
8.0.11:

```
warning MSB3277: Se han encontrado conflictos entre distintas versiones de
"Microsoft.EntityFrameworkCore.Relational" que no se han podido resolver.
  Existía un conflicto entre "…Relational, Version=8.0.11.0" y "…Relational, Version=8.0.30.0".
  Se eligió "…Relational, Version=8.0.11.0" porque era principal y "…8.0.30.0" no lo era.
```

`backend/README.md` declara en su tabla de stack *"Entity Framework Core 8.0.30"*, y el `.csproj` del test
pide `Microsoft.EntityFrameworkCore.InMemory 8.0.30`. Lo que realmente se carga es **8.0.11**.

**2. SDK local sin fijar** — el proyecto apunta a `net8.0` y el `Dockerfile` usa `sdk:8.0`, pero no hay
`global.json` en el repositorio, así que `dotnet test` en esta máquina compiló con **SDK 10.0.302** (hay tanto
SDK 8.0.424 como 10.0.302 instalados). La documentación pide ".NET SDK 8.0" sin que nada lo fuerce.

Ninguno de los dos rompe los 94 tests, pero ambos hacen que **"reproducible" dependa de la máquina**.

## Evidencia

```
$ dotnet --list-sdks
8.0.424  [C:\Program Files\dotnet\sdk]
10.0.302 [C:\Program Files\dotnet\sdk]

$ dotnet test backend.Tests\backend.Tests.csproj
...
C:\Program Files\dotnet\sdk\10.0.302\Microsoft.Common.CurrentVersion.targets(2453,5):
  warning MSB3277: Se han encontrado conflictos entre distintas versiones de
  "Microsoft.EntityFrameworkCore.Relational" ...
...
Correctas! - Con error: 0, Superado: 94, Omitido: 0, Total: 94, Duración: 15 s
```

Versiones declaradas:

| Paquete | Archivo | Versión declarada |
|---|---|---|
| `Npgsql.EntityFrameworkCore.PostgreSQL` | `backend/RemesaSmartSV.csproj:20` | 8.0.11 |
| `Microsoft.EntityFrameworkCore.Design` | `backend/RemesaSmartSV.csproj:12` | 8.0.30 |
| `Microsoft.EntityFrameworkCore.Tools` | `backend/RemesaSmartSV.csproj:16` | 8.0.30 |
| `Microsoft.EntityFrameworkCore.InMemory` | `backend.Tests/backend.Tests.csproj:16` | 8.0.30 |
| `EF Core.Relational` **efectivamente resuelto** | (por MSBuild) | **8.0.11** ⚠️ |

## Pasos para reproducir

1. `dotnet restore backend.Tests\backend.Tests.csproj`
2. `dotnet build backend.Tests\backend.Tests.csproj` → aparecer `warning MSB3277` dos veces.
3. `dotnet list backend\RemesaSmartSV.csproj package --include-transitive | Select-String 'Relational'` → 8.0.11

## Comportamiento esperado

Versiones coherentes y toolchain fijado, para que el mismo commit produzca el mismo build en cualquier máquina
y en CI.

## Corrección sugerida

**1. Subir Npgsql a la versión que trae EF Core 8.0.30** (elimina el conflicto en vez de silenciarlo):

```xml
<PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="8.0.11" />
<!-- cambiar a -->
<PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="8.0.30" />
```

Verificar que la versión de Npgsql 8.x que alinee con EF Core 8.0.30 exista y que las pruebas de integración
sigan en verde tras el cambio. Si no se puede alinear, la alternativa mínima es **corregir la tabla del
README** para que diga la versión real, y añadir `<TreatWarningsAsErrors>MSB3277</TreatWarningsAsErrors>` en el
proyecto de pruebas para que el conflicto no vuelva a aparecer en silencio.

**2. Fijar el SDK con `global.json`** en la raíz de cada repo:

```json
{
  "sdk": {
    "version": "8.0.400",
    "rollForward": "latestFeature"
  }
}
```

Esto hace que `dotnet test` use el SDK 8 como documenta el README y como usa el `Dockerfile`, y evita que un
SDK mayor introduzca cambios de compilación que no están en el radar del equipo.

**3. Añadir `dotnet test` al CI** (hoy no corre, ver `SEC-10`), con `--warnaserror` para que MSB3277 no pase
desapercibido.

## Impacto

- Bajo en impacto inmediato: los 94 tests pasan y la demo funciona.
- Alto en reproducibilidad: la rúbrica da 10% a "despliegue reproducible con Docker y CI/CD" y 25% a calidad
  técnica. Que el build dependa del SDK instalado y que la versión de EF Core no sea la documentada son
  cosas que un jurado técnico puede detectar.
- Riesgo real: si Npgsql 8.0.11 y EF Core 8.0.30 divergen en comportamiento, **las pruebas con InMemory
  pueden no reflejar lo que hace el backend con Npgsql real**. Es exactamente la clase de diferencia que
  produjo el error 500 de `BUG-05` (que solo apareció contra PostgreSQL real).

## Entorno verificado
Windows · SDK 8.0.424 y 10.0.302 instalados · 94/94 tests en verde · 2026-09-27
Caso de prueba asociado: `dotnet test backend.Tests\backend.Tests.csproj` (warning MSB3277)
