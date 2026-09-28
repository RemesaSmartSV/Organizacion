# SEC-02 — Contraseña de PostgreSQL en texto plano en `docker-compose.yml`

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Crítico] Contraseña de PostgreSQL `<POSTGRES_PASSWORD>` hardcodeada en `docker-compose.yml`, reutilizada por la API y con el puerto 5432 publicado al host**

## Labels sugeridos
`security` · `secrets` · `docker` · `prioridad: crítica`

## Descripción

El `docker-compose.yml` del backend declara credenciales de la base de datos **en texto plano y versionadas**, y además reutiliza esa misma contraseña en la cadena de conexión del servicio de la API:

`backend/docker-compose.yml:12`
```yaml
POSTGRES_PASSWORD: <POSTGRES_PASSWORD>
```

`backend/docker-compose.yml:31`
```yaml
- ConnectionStrings__DefaultConnection=Host=postgres_db;Port=5432;Database=RemesaSmartDB;Username=postgres;Password=<POSTGRES_PASSWORD>
```

`backend/docker-compose.yml:14` publica el puerto de la base de datos al host:
```yaml
- "5432:5432"
```

Consecuencias:

1. Cualquiera con el repositorio conoce la contraseña del usuario `postgres` (superusuario de la base) del entorno.
2. Como el puerto `5432` está mapeado al host, esa contraseña sirve para conectarse **directamente a la base de datos desde la máquina del desarrollador** (o desde el runner si el compose corre en un host compartido), sin pasar por la API ni por su autorización.
3. Si ese mismo compose se reutiliza en un entorno compartido/staging, la base contiene **datos financieros reales de usuarios** (correos, movimientos, presupuestos) accesibles con una credencial pública.
4. La contraseña es reutilizada en dos sitios: cambiarla exige editar dos líneas y es fácil olvidar una.

## Pasos para reproducir

```powershell
# 1. Extraer la credencial del repositorio
Select-String -Path backend\docker-compose.yml -Pattern "POSTGRES_PASSWORD|Password="
```

```powershell
# 2. Conectar a la base del entorno levantado por el compose, usando la credencial del repo
docker compose -f backend\docker-compose.yml up -d postgres_db
psql "host=localhost;port=5432;dbname=RemesaSmartDB;user=postgres;password=<POSTGRES_PASSWORD>" -c "\dt"
psql "host=localhost;port=5432;dbname=RemesaSmartDB;user=postgres;password=<POSTGRES_PASSWORD>" -c "select \"Correo\", \"Rol\" from \"Usuarios\";"
```

## Comportamiento esperado

1. El repositorio no contiene ninguna credencial utilizable de base de datos.
2. El compose lee la credencial de una variable de entorno con valor por defecto **solo para desarrollo** (`.env` no versionado) o falla claramente si no está definida.
3. El puerto de PostgreSQL no se publica al host salvo que se pase un flag explícito (`profiles: [debug]`), porque la API ya habla con la BD por la red interna del compose.

## Causa probable y corrección sugerida

**Causa:** el compose se escribió para "que funcione al primer `docker compose up`", con valores por defecto incrustados. El `README.md` ya documenta el camino correcto (*user-secrets* / variable de entorno) para correr sin Docker, pero el compose se quedó atrás.

**Corrección:**
```yaml
# backend/.env  (NO versionado; añadir a .gitignore)
POSTGRES_PASSWORD=<contraseña local>
# backend/docker-compose.yml
services:
  postgres_db:
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?define POSTGRES_PASSWORD en .env}
    ports:            # solo si se necesita conectar desde el host
      - "127.0.0.1:5432:5432"   # atado a loopback, no 0.0.0.0
  backend_api:
    environment:
      - ConnectionStrings__DefaultConnection=Host=postgres_db;Port=5432;Database=RemesaSmartDB;Username=postgres;Password=${POSTGRES_PASSWORD}
      - Jwt__Key=${JWT_KEY:?define JWT_KEY en .env}
```
Y en `appsettings.json` dejar la conexión como placeholder (ya lo está: `"Password="` vacío) documentando que **sin `ConnectionStrings__DefaultConnection` la app debe fallar al arrancar**, en vez de intentar conectar sin contraseña (ver `ApplicationDbContextFactory`, que hoy happily connectaría con password vacío si la BD lo permite).

**Extra recomendado:** añadir `.env` a `.gitignore` (hoy solo están `secrets.json` y `appsettings.*.local.json`) y un `gitleaks` en CI (ver SEC-10) para que este tipo de literals no vuelva a entrar.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC02_LaContrasenaDePostgresEstaEnTextoPlanoEnElComposeYSeReutilizaEnLaApi` (falla cuando se corrige).

## Entorno verificado
- `develop` · PostgreSQL 16 + API .NET 8 en `docker-compose.yml`
- Revisión estática + 42 casos xUnit — 2026-09-27
- Caso: CP-S-36
- Relacionado: SEC-01 (misma familia: secreto en texto plano), SEC-09 (el puerto publicado sin TLS es lo que hace explotable esta credencial desde fuera del compose)
