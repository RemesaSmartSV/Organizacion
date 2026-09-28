> Este archivo es la descripcion del Pull Request #80 de `RemesaSmartSV/Organizacion`
> (rama `qa/auditoria-seguridad-issue-76`). Se versiona para que quede en el historial
> y para poder pegarlo en la web sin depender de la CLI de GitHub.
> Para actualizar el PR: copiar el contenido del archivo en el campo de descripcion, o
> `Get-Content -Raw <este archivo> | gh pr edit 80 --body-file -`.
## Que hace este PR

Trabajo de QA del backend de RemesaSmart SV. Solo pruebas y documentacion: **no se toca codigo del backend**. El codigo vive en el repo `RemesaSmartSV/backend` y esta replicado aqui solo para poder compilar las pruebas (`.gitignore` lo excluye).

Cierra #76.

Son dos entregas en la misma rama:

1. **Auditoria de seguridad** (`c2bd704`, `e896bb5`): 42 casos automatizados y 10 issues, `SEC-01` a `SEC-10`.
2. **Ejecucion de la demo end-to-end** (`d7fa293`, `52989dd`, `03d869c`): 40 comprobaciones sobre la API real en Docker y 11 issues nuevos, `DEMO-01` a `DEMO-11`.

---

## Parte 1 - Auditoria de seguridad

Documentacion en `doc/qa/SEGURIDAD/`:

- `Auditoria_Seguridad.md` - informe de la auditoria
- `Casos_Prueba_Seguridad.md` - 42 casos con ID `SEC-xx`
- `issues/SEC-01..SEC-10` - un archivo por hallazgo
- `resultados_SEGURIDAD.csv` / `.json` - resultados maquinables

Pruebas en `backend.Tests/SeguridadTests.cs`, 5 clases sobre el codigo real (EF Core InMemory, `JwtSecurityTokenHandler`, reflexion y escaneo de archivos de configuracion versionados).

Los tests con prefijo `Vuln_SECxx_` **afirman que la vulnerabilidad sigue presente**: pasan hoy y quedaran en rojo cuando se corrija el hallazgo. Es intencional, para que el equipo vea cuando algo se arregla.

| # | Hallazgo |
|---|---|
| SEC-01 | Clave de firma JWT hardcodeada |
| SEC-02 | Contrasena de PostgreSQL hardcodeada |
| SEC-03 | Sin cabeceras de seguridad |
| SEC-04 | Sin rate limit en login |
| SEC-05 | Campos de texto sin saneamiento (XSS) |
| SEC-06 | Rol sin lista blanca |
| SEC-07 | JWT sin revocacion ni control de reloj |
| SEC-08 | `ASPNETCORE_ENVIRONMENT=Development` en compose |
| SEC-09 | HTTP sin TLS en el contenedor |
| SEC-10 | Higiene de configuracion y CI |

---

## Parte 2 - Demo end-to-end

Documentacion en `doc/qa/DEMO-E2E/` (punto de entrada: **`README.md`**).

Recorrida de los 10 pasos del guion mas el cierre de sesion, contra el backend levantado en Docker, sobre volumen limpio.

**Resultado de la corrida del 27-09-2026: 28 de 40 comprobaciones en verde.**

Veredicto por paso:

| Paso | Resultado | Nota |
|---|---|---|
| 1. Despliegue | 1/2 | El comando documentado falla: falta el contexto `../frontend` |
| 2. Registro | 4/4 | |
| 2b. Login | 2/4 | claim `role` con URI larga y sin `iat` |
| 3. Miembro | 3/3 | |
| 4. Remesa | 4/4 | `Tipo` es texto libre |
| 5. Gasto | 2/2 | |
| 6. Tablero | 2/3 | No hay endpoint de tablero |
| 7. Presupuesto | 3/4 | La API no devuelve el consumo |
| 8. Alerta | 2/3 | No hay alerta en la API. *Momento clave de la demo* |
| 9. Meta | 5/6 | Falta el ritmo mensual |
| 10. Tips | 0/2 | La seccion sale vacia |
| 11. Cierre de sesion | 0/3 | El token sigue vivo tras el logout |

### Los 3 problemas que pueden hacer fracasar la demo

1. **`DEMO-01` - el comando de arranque documentado no funciona.** `docker compose up --build` es el paso 1 del guion y aborta con `path "...\frontend" not found`. Hay que levantar `postgres_db backend_api` y el frontend por separado.
2. **`DEMO-02` - Educacion Financiera sale vacia.** `GET /api/TipsFinancieros` devuelve `0` filas: la migracion `InitialCreate` no siembra ningun tip. El paso 10 pide mostrar el tip relacionado con la actividad de la familia y no hay nada.
3. **`DEMO-04` - la alerta de presupuesto excedido no existe en la API.** Es el momento que el guion marca como *"el momento clave de la demo: hacer pausa aqui"*. No hay campo, endpoint ni codigo HTTP que indique el exceso: depende por completo del frontend.

### Hallazgos nuevos

| # | Resumen | Prioridad |
|---|---|---|
| `DEMO-01` | `docker compose up --build` falla: falta `../frontend` | Alta, bloqueante |
| `DEMO-02` | Educacion Financiera sin contenido sembrado | Alta, bloqueante |
| `DEMO-03` | La API se cae en el primer arranque sobre base limpia | Alta |
| `DEMO-04` | La API no entrega alerta de presupuesto excedido | Alta, bloqueante |
| `DEMO-05` | `Movimiento.Tipo` sin lista blanca | Media |
| `DEMO-06` | `Presupuesto` no expone consumo ni porcentaje | Media |
| `DEMO-07` | No hay endpoint de tablero o resumen | Media |
| `DEMO-08` | La remesa se distingue solo por `origenEmisora` | Media |
| `DEMO-09` | `MetaAhorro` sin faltante ni ritmo mensual | Media |
| `DEMO-10` | `EducacionFinanciera` depende de una `Categoria` por hogar | Media |
| `DEMO-11` | Conflicto `EF Core.Relational` 8.0.11 vs 8.0.30, SDK sin fijar | Baja |

Los dos con codigo de correccion listo: `DEMO-03` (healthcheck en `depends_on` y reintento sobre `Migrate()`) y `DEMO-11` (alinear Npgsql y agregar `global.json`).

### Hallazgos previos revalidados

Sin repetir la auditoria, se confirmo contra la API viva:

- **Se reproducen:** `BUG-01`, `SEC-03`, `SEC-07`, `SEC-08`
- **Corregido:** `BUG-05` - el filtro de presupuestos por `anio`/`mes` responde 200 contra PostgreSQL real
- `dotnet test` en verde: **94/94**

### Afirmaciones de la documentacion que la ejecucion desmintio

- El README declara *Entity Framework Core 8.0.30*; el build resuelve `Relational` 8.0.11 (MSB3277) y no hay `global.json`, asi que `dotnet test` compilo con el SDK 10.0.302 y no con el 8 documentado. Ver `DEMO-11`.
- El paso 1 del guion da por hecho que `docker compose up --build` levanta los tres servicios. No levanta ninguno.

---

## Como reproducir la demo

```powershell
cd backend
docker compose up -d --build postgres_db backend_api
# esperar ~20 s a que la API responda
cd ..
powershell -ExecutionPolicy Bypass -File doc\qa\DEMO-E2E\Ejecutar_Demo_E2E.ps1
```

Las pruebas de seguridad:

```powershell
dotnet test backend.Tests\backend.Tests.csproj
```

---

## Alcance y limitaciones

- **El repositorio `frontend/` no esta clonado**, asi que no se pudo auditar la UI ni ejecutar la demo visual. Todo lo verificado es a nivel de API.
- Los checks cuyo esperado es *"la API entrega X"* fallan cuando el dato lo tiene que calcular el frontend. Se distinguen de los bugs de backend en `doc/qa/DEMO-E2E/README.md` y **no son bugs del backend**: son riesgos de demostracion.
- `doc/qa/DEMO-E2E/evidencia_raw.log` (52 KB, requests/responses crudas) queda **fuera del control de versiones**: contiene tokens de sesion vivos y la clave que los firma esta versionada en el repo del backend (`SEC-01`), asi que subirlo permitiria falsificar sesiones de Admin. La evidencia versionada es el CSV/JSON y los fragmentos citados en cada issue.
- `doc/qa/SEGURIDAD/evidencia_raw.log` si esta versionado por ser un stub sin credenciales, aunque la regla `*.log` de `.gitignore` lo excluya: quedo trackeado en `e896bb5`, antes de que existiera la regla, y las reglas de `.gitignore` no desenraizan archivos ya versionados.
- La contrasena `Demo1234!` de la bateria es una credencial de descarte, no un secreto real, y sigue la misma convencion que ya usa `doc/qa/FILTROS-PAGINACION/Ejecutar_Pruebas_Filtros_Paginacion.ps1`.
- Docker quedo con las familias creadas por las dos ejecuciones de la bateria. Para arrancar en limpio: `docker compose down -v` y esperar a que la API responda, porque el primer arranque falla una vez (ver `DEMO-03`).

## Revisar

Son 7 commits y 40 archivos, casi todo `.md` y artefactos de prueba. Lo que vale la pena mirar primero:

1. `doc/qa/DEMO-E2E/README.md` - el informe principal
2. `doc/qa/SEGURIDAD/Auditoria_Seguridad.md` - la auditoria
3. Los 3 commits de la demo end-to-end, al final del historial
