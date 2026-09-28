# DEMO-08 — La remesa se distingue solo por convención de `origenEmisora`

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Movimientos] Nada en el modelo marca un movimiento como remesa: la tarjeta y la vista de remesas del tablero dependen de que `origenEmisora` venga vacía o no**

## Labels sugeridos
`feature` · `movimientos` · `api-contract` · `prioridad: media`

## Descripción

El nombre del proyecto, el paso 4 de la demo y el valor agregado del guion giran en torno a un solo
diferencial: **separar la remesa de un ingreso común**.

> Paso 1 — **Registro**. […] cuando es remesa, **la entidad emisora que la envió**. Eso último es lo que nos
> permite separar la remesa de un ingreso común, y por eso el tablero tiene una vista exclusiva de remesas.

Lo verificado: el campo `OrigenEmisora` **existe, es persistente y conserva UTF-8 correctamente**
(`"Tío Carlos - Los Ángeles"` vuelve intacto, check `CP-D16` en verde). Lo que no existe es cualquier
**contrato** que diga qué es una remesa:

- No hay campo booleano `EsRemesa` ni enum de origen (`Remesa`, `Salario`, `Trabajo`).
- No hay filtro `GET /api/Movimientos?esRemesa=true` ni `?soloRemesas=true`.
- `OrigenEmisora` es un `string?` libre: **cualquier ingreso puede llevar un emisor, y cualquier remesa puede
  dejarlo vacío**. Un ingreso de salario con el campo diligenciado se contaría como remesa; una remesa sin
  emisor no se contaría.

La "tarjeta violeta de remesas" y la "vista exclusiva de remesas" se construyen, entonces, con una heurística
silenciosa: `origenEmisora IS NOT NULL AND origenEmisora <> ''`.

## Evidencia

Check `CP-D22`:

```
[FAIL] CP-D22  La API distingue la remesa de un ingreso comun
         esperado: campo o filtro de remesas en la respuesta
         obtenido: solo origenEmisora en 1 movimiento(s), sin flag ni filtro propio
```

Filtros realmente disponibles en `GET /api/Movimientos` (firma del método, `MovimientosController.cs:20`):

```csharp
public async Task<ActionResult<IEnumerable<Movimiento>>> GetMovimientos(
    [FromQuery] int? categoriaId, [FromQuery] string? tipo)
```

Solo dos filtros. No hay nada sobre remesas.

## Pasos para reproducir

1. Registrar una remesa de $400 con `origenEmisora: "Tío Carlos"`.
2. Registrar un ingreso de $1.200 de salario **con** `origenEmisora: "Patronal"` (nada lo impide).
3. El total de "remesas" del tablero, si filtra por `origenEmisora` no vacío, da $1.600 en vez de $400.

## Comportamiento esperado

Marcar el origen del ingreso en el modelo, para que la pregunta "¿cuánto fue remesa y cuánto fue salario?" —que
el guion presenta como una de las respuestas que el tablero da por primera vez— sea respondible con un dato y no
con una convención:

```csharp
public enum OrigenIngreso { Remesa = 1, Salario = 2, Trabajo = 3, Otros = 4 }

public class Movimiento
{
    [Required] public string Tipo { get; set; }        // Ingreso | Gasto  (ver DEMO-05)
    public OrigenIngreso? Origen { get; set; }         // nuevo, solo aplica a Ingreso
    [StringLength(100)] public string? OrigenEmisora { get; set; }  // "quién envió", no "es remesa"
}
```

Con eso, el filtro y el agregado se vuelven exactos:

```
GET /api/Tablero?anio=2026&mes=9      ->  "totalRemesas": 400.00
GET /api/Movimientos?origen=Remesa    ->  solo las remesas
```

Como es un campo nuevo y nullable, la migración es aditiva y no rompe datos existentes.

## Causa

`Entities/Movimiento.cs:40-42` solo declara `OrigenEmisora`; el modelo nunca tuvo una noción de "tipo de
ingreso". `OrigenEmisora` quedó cumpliendo dos roles —*quién envió la remesa* y *marcar que es remesa*— que
el modelo debería separar.

## Impacto

- La tarjeta de remesas, uno de los diferenciadores del producto, depende de una heurística no documentada.
- El dato es ambiguo en la base: no se puede distinguir "remesa de un familiar" de "remesa de una remesadora".
- El nombre del proyecto se apoya en esta separación: si la separación es frágil, el argumento central del
  nombre queda débil si el jurado pregunta por la implementación.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · 2026-09-27
Caso de prueba asociado: **CP-D16** (verde) y **CP-D22** (rojo) de `Ejecutar_Demo_E2E.ps1`)
