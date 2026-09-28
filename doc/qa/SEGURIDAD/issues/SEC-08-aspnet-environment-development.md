# SEC-08 — El compose arranca la API en modo `Development`

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Media] `docker-compose.yml` fija `ASPNETCORE_ENVIRONMENT=Development`: expone Swagger UI y la página de detalle de excepciones (stack traces) en cualquier despliegue que reutilice ese compose**

## Labels sugeridos
`security` · `docker` · `informacion-divulgada` · `owasp-a05` · `prioridad: media`

## Descripción

`backend/docker-compose.yml:30`
```yaml
- ASPNETCORE_ENVIRONMENT=Development
```

Con ese valor, el código de `backend/Program.cs:78-82` activa dos cosas que **no deben existir fuera del entorno de un desarrollador**:

```csharp
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
```

1. **Swagger UI en `/swagger`**: publica la superficie completa de la API (rutas, esquemas, cuerpos de ejemplo) y permite a cualquiera **ejecutar operaciones** contra los datos reales solo con un token válido. En una app que maneja datos financieros de usuarios, esto es un mapa de la API entregado.
2. **Página de detalle de excepciones del developer** (agregada automáticamente por `WebApplication` en `Development`): ante un error no controlado devuelve **stack trace, rutas de archivos y fragmentos de la cadena de conexión** (host, base de datos, usuario) en la respuesta HTTP. Es exactamente la información que ayuda a un atacante a mapear la infraestructura (CWE-209).

Además, en el mismo entorno de desarrollo:
- `SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true` (`Program.cs:13`) desactiva la validación implícita de `[Required]` en no-nullables, de modo que un body incompleto puede llegar a la lógica de negocio en lugar de producir `400`.
- El `appsettings.Development.json` no añade logging sensible hoy, pero cualquier `LogLevel` a `Debug` que se añada en el futuro se imprintará en los logs del despliegue por usar este mismo compose.

**Nota de alcance:** con el compose actual el riesgo es bajo porque todo ocurre en la máquina del desarrollador. Se reporta porque ese mismo `docker-compose.yml` es el camino natural de despliegue para un ambiente de pruebas/demo compartido, y es trivial reutilizarlo por error.

## Pasos para reproducir

```powershell
docker compose -f backend\docker-compose.yml up -d --build postgres_db backend_api

# 1. Swagger UI accesible
curl.exe -o NUL -w "%{http_code}" http://localhost:8080/swagger/index.html      # 200

# 2. Detalle de excepciones: provocar un error no controlado
curl.exe -i http://localhost:8080/api/TipsFinancieros/abc
# HTTP/1.1 500 ...  + cuerpo con stack trace de RemesaSmartSV.Controllers.TipsFinancierosController
#                    y datos de la cadena de conexión (Host=postgres_db;Database=RemesaSmartDB...)
```

## Comportamiento esperado

1. El entorno se configura por variable, con default seguro: `ASPNETCORE_ENVIRONMENT: ${ASPNETCORE_ENVIRONMENT:-Production}`.
2. Swagger solo se publica cuando se pide explícitamente (p. ej. un perfil `debug` o `ASPNETCORE_ENVIRONMENT=Development` pasado a propósito).
3. Los errores no controlados devuelven `500` con cuerpo genérico y un identificador de correlación; el detalle va al log.

## Causa probable y corrección sugerida

**Causa:** valor por defecto cómodo para desarrollo local que quedó hardcodeado en el compose de "un solo comando".

**Corrección:**
```yaml
# backend/docker-compose.yml
services:
  backend_api:
    environment:
      - ASPNETCORE_ENVIRONMENT=${ASPNETCORE_ENVIRONMENT:-Production}
      - Jwt__Key=${JWT_KEY:?define JWT_KEY en .env}
      - ConnectionStrings__DefaultConnection=Host=postgres_db;Port=5432;Database=RemesaSmartDB;Username=postgres;Password=${POSTGRES_PASSWORD}
```
```bash
# backend/.env (NO versionado) para desarrollo
ASPNETCORE_ENVIRONMENT=Development
POSTGRES_PASSWORD=<local>
JWT_KEY=<local>
```
```csharp
// Program.cs -> proteger el arranque en cualquier entorno, no solo Development
if (app.Environment.IsDevelopment() || app.Configuration.GetValue<bool>("Swagger:Enabled"))
    app.UseSwaggerUI();

app.UseExceptionHandler("/error");   // respuesta 500 generica
```
Y como mejora, sustituir el bloque `if (app.Environment.IsDevelopment())` por un flag explícito (`appsettings.Development.json` = `true`, producción = `false`) para que la decisión no dependa solo del nombre del entorno.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC08_ElComposeArrancaLaApiEnDevelopmentExpuestoASwaggerYAlDetalleDeErrores` (falla al corregir).
La verificación del cuerpo 500 con stack trace requiere la API levantada (batería HTTP con Docker, patrón `doc/qa/HU01/Ejecutar_Pruebas_HU01.ps1`).

## Entorno verificado
- `develop` · `docker-compose.yml` (PostgreSQL 16 + API .NET 8)
- Revisión estática + 42 casos xUnit — 2026-09-27
- Caso: CP-S-39
- Relacionado: SEC-10 (validación de modelo desactivada, misma línea de código), SEC-09 (TLS), SEC-03 (cabeceras)
