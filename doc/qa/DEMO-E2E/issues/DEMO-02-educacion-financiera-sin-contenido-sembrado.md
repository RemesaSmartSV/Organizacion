# DEMO-02 — Educación Financiera sin contenido: la migración no siembra ningún tip

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[UX / Datos] `GET /api/TipsFinancieros` devuelve 0 filas en una base recién migrada: el paso 10 de la demo muestra una pantalla vacía**

## Labels sugeridos
`bug` · `datos` · `contenido` · `bloqueante-demo` · `prioridad: alta`

## Descripción

El paso 10 del guion de la demo en vivo es:

> 10. Abrir **Educación Financiera** y mostrar el tip relacionado con la actividad de la familia.

Con la base de datos freshly migrated —es decir, el estado que produce `docker compose up --build`, el comando
que el propio guion indica— **no hay ni un solo tip que mostrar**. La sección de Educación Financiera es
presentada como uno de los cuatro pasos de la solución ("Aprender · Educación financiera en el contexto de la
familia") y como argumento de diferenciación frente a un cuaderno digital, y se presenta vacía.

## Evidencia

```powershell
$ curl -s http://localhost:8080/api/TipsFinancieros
[]
```

Conteo directo sobre la base limpia, después de `docker compose down -v` + `up -d --build`:

```
      tabla      |  n
-----------------+------
 Hogares         |    0
 Usuarios        |    0
 Categorias      |    0
 Movimientos     |    0
 Presupuestos    |    0
 MetasAhorro     |    0
 Aportes         |    0
 TipsFinancieros |    0      <-- la sección que se presenta en el paso 10
(8 rows)
```

La migración `backend/Migrations/20260811193629_InitialCreate.cs` **no tiene ninguna llamada a `HasData` ni
`InsertData`**; solo crea la tabla y el índice:

```
Migrations\20260811193629_InitialCreate.cs:128:  name: "TipsFinancieros",
Migrations\20260811193629_InitialCreate.cs:139:  table.PrimaryKey("PK_TipsFinancieros", x => x.IdTip);
Migrations\20260811193629_InitialCreate.cs:141:  name: "FK_TipsFinancieros_Categorias_IdCategoria",
```

## Pasos para reproducir

1. `cd backend && docker compose down -v && docker compose up -d --build postgres_db backend_api`
2. Esperar ~20 s.
3. `curl http://localhost:8080/api/TipsFinancieros` → `[]`
4. Abrir la sección de Educación Financiera en el frontend: la grilla de tarjetas sale vacía.

## Comportamiento esperado

Que exista contenido de educación financiera *out of the box*, por al menos dos vías (a decidir por el equipo):

1. **Seed en la migración** (`HasData` / `InsertData`) con 6–10 tips en español, para que `docker compose up`
   deje la aplicación en estado presentable. Es la opción que hace que el checklist "base de datos con datos de
   ejemplo" se cumpla sin pasos manuales.
2. **Script de carga versionado** (`doc/qa/…/seed` o `backend/seed.sql`) documentado como paso previo
   obligatorio del checklist, para que el contenido viva fuera del historial de migraciones (recomendable si el
   contenido va a cambiar seguido).

⚠️ Restricción a tener en cuenta al sembrar: `EducacionFinanciera.IdCategoria` es **obligatorio** y es FK a
`Categorias`, que es una tabla **por hogar** (ver `DEMO-10`). Sembrar un tip exige crear también una categoría,
lo que acopla contenido global a datos de una familia concreta. Resolver antes `DEMO-10` o sembrar la categoría
en un hogar semilla conocido.

## Causa

Ninguna migración siembra datos. `Program.cs` solo ejecuta `db.Database.Migrate()` (líneas 71-75), que crea el
esquema y nada más. El checklist de la demo pide "base de datos con datos de ejemplo" pero ningún artefacto del
repo los siembra.

## Impacto

- El paso 10 de la demo se presenta vacío: 3 minutos de exposición sin contenido, o un pico de improvisación si
  el frontend muestra un estado vacío no diseñado.
- Refuerza el argumento del jurado sobre "educación financiera que llega a tiempo": sin contenido, la
  diferenciación frente a un cuaderno no es demostrable.
- Riesgo de que alguien suba tips a mano a una base de desarrollo y el comportamiento difiera entre máquinas.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · base limpia (`down -v`) · 2026-09-27
Caso de prueba asociado: **CP-D02** y **CP-D36** (de `Ejecutar_Demo_E2E.ps1`)
