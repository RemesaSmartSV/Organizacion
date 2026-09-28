# SEC-09 — La API y la base de datos viajan por HTTP sin TLS

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Media] El contenedor sirve la API por `http://+:8080` con el puerto publicado y PostgreSQL con `5432:5432`: el JWT y los datos de remesas viajan en claro, y `UseHttpsRedirection()` no tiene HTTPS detrás**

## Labels sugeridos
`security` · `tls` · `docker` · `owasp-a02` · `prioridad: media`

## Descripción

Hay una incoherencia entre el código y el despliegue:

- `backend/Program.cs:84` llama a `app.UseHttpsRedirection()`.
- `backend/Dockerfile:19` publica `ENV ASPNETCORE_URLS=http://+:8080` (solo HTTP, sin certificado).
- `backend/docker-compose.yml:33` publica `"8080:8080"` (bind a `0.0.0.0`).
- `backend/docker-compose.yml:14` publica `"5432:5432"` para PostgreSQL, también sin TLS y **sin atar a loopback**.

Consecuencias:

1. `UseHttpsRedirection()` sin `ASPNETCORE_HTTPS_PORT`/certificado configurado **avisa en el log y deja pasar** la petición en claro: el código aparenta una protección que en el contenedor no existe. Quien lea `Program.cs` puede creer lo contrario.
2. El **JWT viaja en claro** en la cabecera `Authorization` en cada request autenticado. Cualquiera en la misma red (otra máquina en la LAN, contenedor vecino, hotspot) puede capturarlo y reutilizarlo **sin crackear nada** (el token es un bearer: quien lo tiene, es el usuario). Con SEC-07 (sin revocación) el token robado sirve 8 h.
3. Los datos de remesas (movimientos, presupuestos, correos) circulan sin cifrar, con impacto directo en privacidad.
4. `5432:5432` en `0.0.0.0` hace la base alcanzable desde la red local con la credencial de SEC-02.

## Pasos para reproducir

```powershell
# 1. La redirección no aplica: la respuesta llega en claro y sin aviso en el cliente
curl.exe -i http://localhost:8080/api/TipsFinancieros
# HTTP/1.1 200 OK   (no hay 307 a https)

# 2. El warning del servidor delata que no hay HTTPS detrás
docker compose -f backend\docker-compose.yml logs backend_api | Select-String "HTTPS redirection"
# warn: Failed to determine the https port for redirect.

# 3. La base de datos es alcanzable desde el host, sin TLS
psql "host=localhost;port=5432;dbname=RemesaSmartDB;user=postgres;password=<POSTGRES_PASSWORD>" -c "select 1"
```

## Comportamiento esperado

1. Fuera del entorno local, la API se sirve **solo** por HTTPS (directo o detrás de un proxy/ingress que termine TLS), y `UseHttpsRedirection()` tiene un destino real.
2. El puerto de PostgreSQL no se publica al host, o se publica atado a `127.0.0.1` y solo en el perfil de desarrollo.
3. HSTS activo en environments con dominio real (ver SEC-03).

## Causa probable y corrección sugerida

**Causa:** el compose se Pensó para desarrollo (rápido, sin certificados) y `UseHttpsRedirection()` se añadió sin advertir que en ese escenario no hace nada.

**Corrección (documentar + endurecer por entorno):**
```yaml
# backend/docker-compose.yml -> solo desarrollo
services:
  postgres_db:
    ports:
      - "127.0.0.1:5432:5432"     # atado a loopback
  backend_api:
    ports:
      - "127.0.0.1:8080:8080"
```
```dockerfile
# Production: TLS en la app o, mejor, terminado en el proxy
ENV ASPNETCORE_HTTPS_PORT=8443
EXPOSE 8443
```
```nginx
# Alternativa recomendada: nginx/ingress termina TLS y reenvía por la red interna
#   (el compose ya incluye el frontend con proxy Nginx; añadir /api al mismo proxy)
#   -> la red interna del compose puede seguir en http si es privada y no se publica
```
Y documentar en el `README.md` del backend: "en desarrollo la API es http; en cualquier entorno compartido el TLS lo termina el proxy (Nginx/Ingress) y la API no se publica directamente".

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC09_ElContenedorSirveLaApiPorHttpSinTlsYLaBaseDeDatosQuedaExpuestaAlHost` (falla al corregir).
Verificación en vivo (headers y warning de redirección) con la batería HTTP + Docker.

## Entorno verificado
- `develop` · `Dockerfile` + `docker-compose.yml` (PostgreSQL 16, API .NET 8)
- Revisión estática + 42 casos xUnit — 2026-09-27
- Caso: CP-S-40
- Relacionado: SEC-02 (credencial de BD expuesta por el mismo puerto), SEC-03 (HSTS), SEC-07 (el token robado en claro vive 8 h)
