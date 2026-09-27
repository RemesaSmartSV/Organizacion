# SEC-03 — El backend no emite ninguna cabecera de seguridad

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Alta] La API no envía ninguna cabecera de seguridad: faltan `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, HSTS y `Cache-Control`**

## Labels sugeridos
`security` · `headers` · `owasp-a05` · `prioridad: alta`

## Descripción

El pipeline HTTP del backend (`backend/Program.cs:78-88`) no configura ningún middleware de cabeceras de seguridad. La respuesta de **cualquier** endpoint sale sin:

| Cabecera | Para qué sirve | Qué pasa sin ella |
|----------|----------------|-------------------|
| `X-Content-Type-Options: nosniff` | Evita que el navegador interprete una respuesta como HTML/JS | Un recurso de la API puede ser tratado como contenido ejecutable en escenarios de sniffing o de inyección de contenido (agravado por SEC-05) |
| `X-Frame-Options: DENY` / `frame-ancestors` | Impide embeberse en un `<iframe>` | Clickjacking si alguna respuesta llega a renderizarse en el navegador |
| `Referrer-Policy` | Evita filtrar URLs a terceros | Las rutas con identificadores (`/api/Movimientos/{id}`) se filtran en `Referer` |
| `Permissions-Policy` | Desactiva APIs de navegador no usadas | Superficie innecesaria (geolocation, cámara, micrófono) |
| `Cache-Control: no-store` | Evita que datos financieros queden en cachés | Respuestas con datos de remesas cacheables por intermediaries |
| `Strict-Transport-Security` (HSTS) | Obliga a HTTPS tras la primera visita | `UseHttpsRedirection()` redirige pero no pinea: la primera visita es susceptible a *downgrade* |

`UseHttpsRedirection()` (`:84`) existe, pero **HSTS no**: sin él, un atacante que controle la red en la primera visita puede degradar la conexión a HTTP.

## Pasos para reproducir

```powershell
# Con la API levantada (docker compose up -d --build backend_api)
curl.exe -i http://localhost:8080/api/TipsFinancieros
```

Respuesta observada (2026-09-27):
```
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Date: ...
Server: Kestrel
Content-Length: ...

[{"idTip":1,...}]
```
Ninguna cabecera de seguridad presente.

## Comportamiento esperado

Cada respuesta incluye como mínimo:
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer
Permissions-Policy: geolocation=(), camera=(), microphone=()
Cache-Control: no-store
Strict-Transport-Security: max-age=31536000; includeSubDomains   (solo en entornos con HTTPS)
```

## Causa probable y corrección sugerida

**Causa:** el backend se construyó como API pura y no se añadió ningún endurecimiento de respuesta. `Helmet` es una librería de Node, así que aquí lo propio es un middleware pequeño o un paquete de headers para ASP.NET Core.

**Corrección (en `Program.cs`, antes de `UseAuthentication`):**
```csharp
app.Use(async (ctx, next) =>
{
    var headers = ctx.Response.Headers;
    headers["X-Content-Type-Options"] = "nosniff";
    headers["X-Frame-Options"] = "DENY";
    headers["Referrer-Policy"] = "no-referrer";
    headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()";
    headers["Cache-Control"] = "no-store";

    if (!ctx.Request.IsDevelopment())
    {
        app.UseHsts();
        headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
    }

    await next();
});
```
> La **CSP** no va aquí: la API no sirve HTML. La CSP (`default-src 'self'`) debe configurarse en el servidor que sirve el frontend, y es la contraparte obligatoria de SEC-05.

Alternativa con paquete: `builder.Services.AddHttpContextAccessor()` + `NetEscapades.AspNetCore.SecurityHeaders` (middleware `UseSecurityHeaders()`), que además genera un Report-Only para hacer rollout gradual.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC03_NoHayNingunaCabeceraDeSeguridadConfiguradaEnElBackend` (falla cuando se corrige). Complemento manual: `curl -i` de arriba (no cubierta por xUnit porque requiere levantar la app con PostgreSQL).

## Entorno verificado
- `develop` · ASP.NET Core 8.0 · Kestrel
- Revisión estática + 42 casos xUnit — 2026-09-27
- Caso: CP-S-37
- Relacionado: SEC-05 (XSS), SEC-08 (modo `Development` expone más superficie), SEC-09 (HSTS sin TLS real no sirve de nada)
