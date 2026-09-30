> Este archivo es la descripcion del Pull Request de la rama `qa/backlog-mvp3` de
> `RemesaSmartSV/Organizacion`. Se versiona para que quede en el historial y para poder pegarlo
> en la web sin depender de la CLI de GitHub.
> Para actualizar el PR: copiar el contenido del archivo en el campo de descripcion, o
> `Get-Content -Raw <este archivo> | gh pr edit <numero> --body-file -`.
## Que hace este PR

Trabajo de documentacion de QA. **No se toca codigo del backend ni agrega pruebas**: consolida en un
solo documento las siete entregas de QA ya mergeadas (SEGURIDAD, DEMO-E2E, backend-tests, HU01,
HU-05, FILTROS-PAGINACION, PERF) y las prioriza para la proxima iteracion.

No es una entrega nueva: no descubre hallazgos. Reordena y prioriza lo que ya esta medido, y deja
explicito lo que quedo **sin** issue por ser deuda de proceso.

Agrega:

- `doc/qa/BACKLOG-MVP3.md` - el backlog (punto de entrada)
- Enlace al inicio de `doc/test-report.md`

---

## Inventario

28 issues documentados: **27 abiertos + 1 ya corregido** (`BUG-05-01`, regresion verde confirmada
contra PostgreSQL real).

| Severidad | Cantidad | IDs |
|---|---|---|
| Critica | 2 | `SEC-01`, `SEC-02` |
| Alta | 8 | `DEMO-01..04`, `CAT-01`, `SEC-03`, `SEC-04`, `AUTH-02` |
| Media | 15 | `SEC-05..09`, `CAT-02..04`, `AUTH-01`, `DEMO-05..10` |
| Baja | 2 | `SEC-10`, `DEMO-11` |

ADEMas: **14 casos `CONFIRMAR-CON-EQUIPO`** y **7 decisiones de diseno** pendientes del equipo, y
**5 secciones de deuda de proceso** que no tienen issue.

---

## Lo que conviene mirar primero

1. **§2 - P0, ~1 dia.** Orden real, con las dependencias que no se ven leyendo issue por issue:
   - `SEC-01` + `SEC-02`: mover `Jwt:Key` y `POSTGRES_PASSWORD` a variables de entorno y **rotar
     ambos**. La ventana de exposicion esta abierta: la clave de firma esta versionada.
   - `CAT-01`: es el unico issue de **perdida de datos irreversible** del inventario.
   - `DEMO-01`, `DEMO-02`, `DEMO-04`: los tres bloqueantes de la demo.
2. **La advertencia de IDs (§Advertencia).** `BUG-01` y `BUG-02` estan **duplicados** entre
   `backend-tests/issues/` y `HU01/issues/`: designan 4 bugs distintos. Es un defecto de esta misma
   documentacion y hay que resolverlo *antes* de abrir los issues en GitHub, porque despues el ID
   es irreversible. Propongo `CAT-01..04` y `AUTH-01..02`.
3. **§6.1 - por que los bugs anterioresrepeat.** Los dos bugs de datos reales (`CAT-01` por
   `ON DELETE CASCADE` y `BUG-05-01` por `-infinity` de PostgreSQL) escaparon porque la suite xUnit
   corre sobre **EF Core InMemory**, que no reproduce ninguno de los dos. Un `94/94` en verde no
   dice nada sobre la base donde viven los datos de las familias.
4. **§5 - las 14 decisiones.** Es la tarea mas barata del backlog (una reunion) y la que mas riesgo
   deja abierto. El comportamiento real de cada caso ya esta medido y documentado: la reunion es
   para **decidir**, no para investigar. Todo el bloque S2 depende de estas respuestas.
5. **§6.4 - la documentacion afirma capacidades que no existen.** El guion y el `DEMO_GUIDE`
   prometen paginacion, busqueda por texto, alerta de presupuesto, token invalidado al cerrar
   sesion, tip contextual y ritmo mensual. La API no soporta ninguna. Para MVP 3 hay que **corregir
   el material o implementar lo prometido**.

---

## Roadmap propuesto

| Bloque | Contenido | Esfuerzo |
|---|---|---|
| **S0 - Desbloquear** | `SEC-01`, `SEC-02`, `CAT-01`, `DEMO-01`, `DEMO-05`, `DEMO-10`+`DEMO-02`, `DEMO-04`+`DEMO-06` | ~1.5 dias |
| **S1 - Seguridad** | `SEC-03..09`, `AUTH-02`, `SEC-05`, `SEC-06`, `CAT-03` | ~2 dias |
| **S2 - Contrato** | `DEMO-07..09`, `CAT-02`, `CAT-04`, paginacion | ~3 dias |
| **S3 - Calidad** | `DEMO-11`, `SEC-10`, suite de integracion PostgreSQL, tests de frontend | ~2 dias |

`DEMO-04` depende de `DEMO-05` (el filtro por `tipo` es sensible a mayusculas: un `"gasto"` en
minuscula romperia `MontoGastado`) y `DEMO-02` depende de `DEMO-10` (cada tip exige una `Categoria`
que es por hogar, asi que no hay forma limpia de sembrar contenido global).

---

## Nota operativa para quien corrija un `SEC`

Los tests con prefijo `Vuln_SECxx_` **afirman que la vulnerabilidad sigue presente**: pasan hoy y
pasaran a rojo en el momento exacto en que se corrija el hallazgo. Quien lo arregle tiene que
**invertir ese test en el mismo PR**; es el detector, no un falso positivo. El backlog lo recoge en
la definicion de cerrado (§8).

---

## Alcance y limitaciones

- **No se descubrio nada nuevo.** Este PR no corrio pruebas ni levanto el entorno. Si algo no esta
  en el backlog, es porque las baterias no lo midieron, no porque este bien: §6 lista lo que nadie
  ha verificado.
- **El frontend sigue sin auditarse ni probarse.** El repo `RemesaSmartSV/frontend` no esta
  clonado y Node.js no esta instalado en el entorno de QA. Por eso los 6 checks de la demo cuyo
  esperado es *"la API entrega X"* se reportan como riesgo de demostracion, no como bug del
  frontend: desde este repositorio no se puede afirmar cuales compensa el frontend y cuales no.
- El documento mantiene los **rangos de effort** del plan de remediacion de la auditoria
  (`SEGURIDAD/Auditoria_Seguridad.md` §8) y estima el resto de forma explicita. Son estimaciones de
  desarrollo, sin revision ni QA.
- Solo se agregan archivos `.md`. No se toca codigo del backend.

## Revisar

1. `doc/qa/BACKLOG-MVP3.md` - el backlog completo
2. La seccion **P0** (§2) y la **advertencia de IDs**
3. La seccion de **deuda de proceso** (§6)
