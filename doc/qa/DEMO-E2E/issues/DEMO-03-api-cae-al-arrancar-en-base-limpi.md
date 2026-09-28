# DEMO-03 — La API se cae en el primer arranque sobre base limpia (migración sin reintento)

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Deploy] En una base vacía la API muere en el primer arranque con `NpgsqlException`: `Migrate()` no espera a que PostgreSQL esté listo y solo revive por `restart: on-failure`**

## Labels sugeridos
`bug` · `deploy` · `docker` · `disponibilidad` · `prioridad: alta`

## Descripción

Sobre un volumen de base de datos recién creado, el primer arranque del contenedor de la API **termina en
excepción no controlada**. El proceso muere antes de abrir el puerto. Solo vuelve a levantarse porque
`docker-compose.yml` declara `restart: on-failure` y el supervisor de Docker lo reintenta una vez, esta vez con
la base ya lista.

Es decir: el checklist *"docker compose up --build levanta los tres servicios desde limpio"* se cumple **por
suerte, no por diseño**. Si el `restart` no estuviera, la demo no arrancaría nunca; y con una base de datos más
lenta o un entorno más cargado, el número de reintentos deja de estar garantizado.

## Evidencia

`docker compose down -v` seguido de `docker compose up -d --build postgres_db backend_api`:

```
Unhandled exception. Npgsql.NpgsqlException (0x80004005): Failed to connect to 172.18.0.2:5432
   at Microsoft.EntityFrameworkCore.Storage.RelationalConnection.OpenDbConnection(Boolean errorsExpected)
   at Microsoft.EntityFrameworkCore.Storage.RelationalConnection.OpenInternal(Boolean errorsExpected)
   at Microsoft.EntityFrameworkCore.Storage.RelationalConnection.Open(Boolean errorsExpected)
   at Microsoft.EntityFrameworkCore.Migrations.HistoryRepository.Exists()
   at Microsoft.EntityFrameworkCore.Migrations.HistoryRepository.GetAppliedMigrations()
   at Npgsql.EntityFrameworkCore.PostgreSQL.Migrations.Internal.NpgsqlMigrator.Migrate(String targetMigration)
   at Microsoft.EntityFrameworkCore.RelationalDatabaseFacadeExtensions.Migrate(DatabaseFacade databaseFacade)
...
info: Microsoft.EntityFrameworkCore.Migrations[20402]
      Applying migration '20260811193629_InitialCreate'.
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://[::]:8080
```

Estado del contenedor tras la recuperación:

```
$ docker inspect remesasmart_backend --format '{{.RestartCount}}'
1
```

Es decir: **un arranque fallido, un reinicio**, y el segundo intento sí aplica la migración. La segunda corrida
del log ya muestra `Applying migration '20260811193629_InitialCreate'`, lo que confirma que la primera
aplicación del esquema solo ocurrió en el segundo intento.

## Pasos para reproducir

1. `cd backend`
2. `docker compose down -v` (borra el volumen `pgdata`)
3. `docker compose up -d --build postgres_db backend_api`
4. `docker logs remesasmart_backend | Select-String 'Failed to connect'` → aparece la excepción
5. `docker inspect remesasmart_backend --format '{{.RestartCount}}'` → `1`

## Comportamiento esperado

La API debe esperar a que la base esté disponible y aplicar las migraciones con reintentos, sin depender de la
política de reinicio del contenedor para arrancar.

## Causa

Dos causas que se combinan:

**1. `Program.cs:71-75` — la migración se corre sin espera ni reintento:**

```csharp
// Aplicar migraciones pendientes al arrancar (entorno reproducible con Docker)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    db.Database.Migrate();      // <-- un solo intento; si la BD no responde, mata el proceso
}
```

**2. `docker-compose.yml:27-28` — `depends_on` sin condición de salud:**

```yaml
    depends_on:
      - postgres_db            # <-- solo espera a que el contenedor exista, no a que PostgreSQL acepte conexiones
```

`depends_on` sin `condition: service_healthy` solo garantiza el orden de *inicio* del contenedor, no que el
servicio esté listo. `postgres:16-alpine` tarda uno o dos segundos más en inicializar el cluster.

## Corrección sugerida

**Opción A — healthcheck + condición (recomendada, resuelve la causa raíz):**

```yaml
  postgres_db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d RemesaSmartDB"]
      interval: 3s
      timeout: 3s
      retries: 10
      start_period: 5s

  backend_api:
    depends_on:
      postgres_db:
        condition: service_healthy
```

**Opción B — reintentos en el código (defensa en profundidad, útil también fuera de Docker):**

```csharp
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    for (var intento = 1; ; intento++)
    {
        try { db.Database.Migrate(); break; }
        catch (NpgsqlException) when (intento < 10)
        {
            app.Logger.LogWarning("Base de datos no disponible (intento {Intento}/10), reintentando…", intento);
            await Task.Delay(TimeSpan.FromSeconds(3));
        }
    }
}
```

Lo recomendable es **A + B**: A evita el arranque en falso en Docker, y B protege el `dotnet run` local y
cualquier otro host.

## Impacto

- Arranque no determinista desde cero: la demo depende de un reintento del supervisor.
- Con `restart: on-failure` y una base lenta, se puede entrar en un bucle de reinicios; la API queda
  intermitente justo en el momento de presentar.
- La excepción no manejada escribe una traza de pila completa en los logs (relevante también para `SEC-08`,
  por el nivel de exposición del entorno `Development`).
- El checklist de presentación afirma que el entorno "se levanta reproducible con un solo comando": hoy es
  cierto por el `restart`, no por la aplicación.

## Entorno verificado
Docker Desktop 29.7.2 · PostgreSQL 16 (`postgres:16-alpine`) · base limpia · 2026-09-27
Caso de prueba asociado: verificación manual de arranque en base limpia (`doc/qa/DEMO-E2E/README.md`, "Entorno usado")
