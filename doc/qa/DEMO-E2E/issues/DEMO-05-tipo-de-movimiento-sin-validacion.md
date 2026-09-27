# DEMO-05 — `Movimiento.Tipo` sin lista blanca: una remesa se puede guardar como `Gasto`

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Movimientos] `Tipo` es texto libre sin validar: el backend acepta una remesa de $400 clasificada como `Gasto`, y cualquier valor de hasta 20 caracteres**

## Labels sugeridos
`bug` · `movimientos` · `validacion` · `prioridad: media`

## Descripción

`Movimiento.Tipo` solo tiene `[StringLength(20)]`. No hay lista blanca ni validación contra el dominio, así que
`POST` y `PUT` aceptan cualquier texto: `"Ingreso"`, `"Gasto"`, `"ingreso"`, `"INGRESO"`, `"Ingreso "` o
`"xyz"`.

El casoverified más grave para la demo: **una remesa de $400 con entidad emisora se puede registrar con
`tipo: "Gasto"` y el sistema lo acepta con `204 No Content`**. Como el tablero y el filtro de movimientos
dependen de `Tipo` para separar ingresos de gastos, una sola captura equivocada invierte el balance del hogar
sin ninguna señal de error.

Además, como el filtro `GET /api/Movimientos?tipo=` compara con `==` sobre el texto crudo, el mismo movimiento
es invisible si se guardó con distinta capitalización.

## Evidencia

Check `CP-D17` de la batería `doc/qa/DEMO-E2E`:

```
[PASS] CP-D17   Una remesa no se puede registrar con Tipo=Gasto por error de captura
         esperado: rechazo (400) o marca de remesa
         obtenido: ACEPTADA: 204 y ahora Tipo=Gasto
```

Request aceptado (el movimiento es la remesa de $400 del paso 4 de la demo):

```http
PUT /api/Movimientos/1008
{
  "idCategoria": 53, "monto": 400.00, "fecha": "2026-09-27",
  "tipo": "Gasto",                       <-- aceptado
  "descripcion": "Remesa mensual",
  "origenEmisora": "Tío Carlos - Los Ángeles"
}
```

Respuesta: `204 No Content`. Ningún campo indica el cambio ni deja rastro.

## Pasos para reproducir

1. Registrarse y crear una categoría de tipo `Ingreso`.
2. `POST /api/Movimientos` con `{ "monto": 400, "tipo": "Ingreso", "origenEmisora": "Tío Carlos" }` → 201.
3. `PUT /api/Movimientos/{id}` con el mismo cuerpo pero `"tipo": "Gasto"` → **204**, el registro cambia de tipo.
4. `GET /api/Movimientos?tipo=Gasto` → la remesa de $400 aparece como gasto.
5. `GET /api/Movimientos?tipo=ingreso` (minúscula) → `[]`.

## Comportamiento esperado

Rechazar con `400 BadRequest` cualquier `Tipo` fuera del dominio. Lo natural en el modelo es un enum:

```csharp
public enum TipoMovimiento { Ingreso = 1, Gasto = 2 }

public class Movimiento
{
    [Required]
    public TipoMovimiento Tipo { get; set; }
}
```

Con enum, EF Core persiste el valor numérico, el filtro deja de ser sensible a mayúsculas y el compilador
obliga al frontend a no inventar valores. Requiere una migración de la columna `Tipo` de `varchar(20)` a `int`
(conversión de los datos existentes), por lo que conviene planificarlo.

Alternativa de menor riesgo para el MVP: un validador que normalice (`Trim()` + comparación
`OrdinalIgnoreCase`) y devuelva `400` con el conjunto permitido:

```csharp
var permitidos = new[] { "Ingreso", "Gasto" };
var tipo = input.Tipo?.Trim() ?? "";
if (!permitidos.Contains(tipo, StringComparer.OrdinalIgnoreCase))
    return BadRequest(new { message = $"Tipo inválido. Valores permitidos: {string.Join(", ", permitidos)}." });
movimiento.Tipo = tipo;   // se guarda normalizado
```

## Causa

`Entities/Movimiento.cs:33-34` declara `[StringLength(20)] public string Tipo`, sin enum ni lista blanca, y
`MovimientosController.Create`/`Update` (líneas 39-52 y 54-76) no validan el valor.

## Relación con hallazgos existentes

Es **el mismo patrón que ya está reportado** en:

- [BUG-03 (backend-tests)](../../backend-tests/issues/BUG-03-categorias-sin-validacion-tipo.md) — `Categoria.Tipo` sin validar.
- [SEC-06 (SEGURIDAD)](../../SEGURIDAD/issues/SEC-06-rol-sin-lista-blanca.md) — `Usuario.Rol` como texto libre.

El informe de seguridad ya señaló que *"SEC-06 es el mismo patrón que BUG-03 → conviene resolver ambos con
enum/mapa de dominio"*. Este hallazgo agrega el **tercero** del mismo patrón: `Movimiento.Tipo`. La corrección
definitiva es un único mapa de dominio (enum) para `Categoria.Tipo`, `Movimiento.Tipo` y `Usuario.Rol`, y los tres
issues se cierran juntos.

## Impacto

- El balance del tablero puede quedar invertido por una captura equivocada, sin error visible.
- El filtro por tipo de la pantalla de movimientos falla de forma silenciosa por capitalización.
- En la demo, si el expositor elige mal "Ingreso"/"Gasto" en un campo de texto libre, el número del tablero
  sale mal en vivo.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · 2026-09-27
Caso de prueba asociado: **CP-D17** (de `Ejecutar_Demo_E2E.ps1`)
