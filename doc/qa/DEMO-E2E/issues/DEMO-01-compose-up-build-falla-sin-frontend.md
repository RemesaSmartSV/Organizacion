# DEMO-01 — `docker compose up --build` falla: el contexto `../frontend` no existe

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Deploy] El comando de arranque documentado `docker compose up --build` aborta porque el servicio `frontend_web` apunta a un contexto `../frontend` inexistente**

## Labels sugeridos
`bug` · `deploy` · `docker` · `bloqueante-demo` · `prioridad: alta`

## Descripción

El paso 1 de la demo en vivo y el checklist de preparación de `doc/guion-presentacion.md` son, literalmente,
`docker compose up --build` ("mostrar que todo levanta con un comando"). Ese comando **falla** en cuanto se
llega al servicio `frontend_web`, porque su contexto de build apunta a `../frontend`, carpeta que no existe
salvo que el repo `RemesaSmartSV/frontend` esté clonado como carpeta hermana.

Esto significa que la afirmación del guion *"con un solo comando levantamos los tres servicios completos"* y el
punto 1 de la sección de despliegue **no se pueden sostener en una máquina donde el frontend no esté clonado**,
que es el estado por defecto de este repositorio.

## Evidencia

Comando del guion, ejecutado en `backend/`:

```
$ docker compose up --build
Image backend-backend_api Building
Image backend-frontend_web Building
unable to prepare context: path "C:\Users\aemel\...\frontend" not found
#1 [internal] load local bake definitions
---- exit: 1 ----
```

El build de `backend_api` se queda `CACHED` y nunca llega a levantarse, porque Compose aborta antes.

Definición actual (`backend/docker-compose.yml:37-49`):

```yaml
  # 3. Frontend React (requiere el repo `frontend` clonado junto a este repo)
  frontend_web:
    build:
      context: ../frontend
      dockerfile: Dockerfile
```

Warning adicional del mismo comando:

```
the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
```

## Pasos para reproducir

1. Clonar `RemesaSmartSV/backend` (este repositorio) **sin** clonar `RemesaSmartSV/frontend` al lado.
2. Con Docker Desktop levantado, en `backend/`: `docker compose up --build`
3. Observar el error `unable to prepare context: path ".../frontend" not found` y el código de salida 1.

Comando alternativo que **sí** funciona y es el que usa esta entrega:

```powershell
docker compose up -d --build postgres_db backend_api
```

## Comportamiento esperado

Opciones, en orden de preferencia del equipo:

1. **`profiles`**: poner `frontend_web` detrás de un profile opcional (`profiles: ["frontend"]`), de modo que
   `docker compose up --build` levante API + base y solo exija el repo hermano quien quiera el frontend.
2. **Contextos relativos por defecto**: separar el compose del frontend del de la API, o documentar un
   `docker compose -f docker-compose.yml -f ../frontend/docker-compose.yml up --build`.
3. **Precondición explícita**: que el compose falle con un mensaje propio y accionable
   ("cloná RemesaSmartSV/frontend junto a este repo") en vez de un error crudo de paths de Docker.

Además, quitar el atributo `version:` obsoleto (`docker-compose.yml:1`) para silenciar el warning.

## Causa

El `docker-compose.yml` asume una estructura de carpetas que solo se cumple en la máquina del autor
(`RemesasSmart_SV/{backend,frontend}`), y el repositorio de documentación no incluye el frontend, así que
cualquiera que clone solo este repo no puede seguir el guion.

## Impacto

- El **primer punto de la demo** falla de forma visible frente al jurado.
- La promesa de "despliegue reproducible con un comando" (10% de la rúbrica) queda sin demostrar.
- `CP-D01` de la batería `doc/qa/DEMO-E2E` cubre el arranque; los 39 checks restantes se ejecutaron con el
  comando alternativo de dos servicios.

## Entorno verificado
Docker Desktop 29.7.2 · Compose v2 · rama `qa/auditoria-seguridad-issue-76` · 2026-09-27
Caso de prueba asociado: **CP-D01** (de `Ejecutar_Demo_E2E.ps1`)
