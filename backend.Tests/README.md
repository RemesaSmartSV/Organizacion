# Pruebas automatizadas del backend (RemesaSmartSV)

Este repositorio (**Organizacion**) contiene **solo las pruebas y la documentacion de QA**.
El codigo fuente del backend (controllers, entities, services, `appsettings.json`, `docker-compose.yml`)
vive en el repositorio **RemesaSmartSV/backend** y no debe subirse aqui.

## Estructura

| Ruta | Contenido |
|---|---|
| `backend.Tests/` | Suite xUnit (unitarios, seguridad, filtros/paginacion, performance) |
| `doc/qa/` | Casos de prueba, evidencia de ejecucion, auditorias e issues detectados |

## Requisitos para compilar

Los tests referencian el proyecto del backend, por lo que necesita estar disponible localmente:

- .NET SDK 8.0
- Una copia del repositorio `RemesaSmartSV/backend`

## Como ejecutar

Cloná el backend como **carpeta hermana** del repo Organizacion (ruta por defecto `../backend`):

```bash
git clone https://github.com/RemesaSmartSV/Organizacion.git
git clone https://github.com/RemesaSmartSV/backend.git   # debe quedar junto a Organizacion/
cd Organizacion
dotnet test backend.Tests/backend.Tests.csproj
```

Si el backend esta en otra ruta, indicala explicitamente:

```bash
dotnet test backend.Tests/backend.Tests.csproj -p:BackendProjectPath="C:\ruta\backend\RemesaSmartSV.csproj"
```

Si el proyecto del backend no se encuentra, la compilacion falla con un mensaje que explica
como resolverlo (propiedad `BackendProjectPath`).

## Suite de seguridad

`backend.Tests/SeguridadTests.cs` cubre 42 casos (XSS, CSRF, JWT, secretos, cabeceras, rate limiting).
Los hallazgos estan documentados en `doc/qa/SEGURIDAD/` (issues `SEC-01`..`SEC-10`).

Los valores de credenciales citados en la documentacion de hallazgos aparecen **enmascarados**
(`<JWT_KEY>` / `<POSTGRES_PASSWORD>`). Los valores reales no se versionan: deben rotarse y量身izarse
con `dotnet user-secrets set` o variables de entorno (`Jwt__Key`, `ConnectionStrings__DefaultConnection`).
