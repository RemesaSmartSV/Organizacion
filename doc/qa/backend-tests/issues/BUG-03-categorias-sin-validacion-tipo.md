# BUG-03 — Categorías sin validación del campo `Tipo` (se aceptan valores arbitrarios)

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Categorías] `POST/PUT /api/Categorias` aceptan cualquier valor en `tipo`; el contrato esperado es solo `Ingreso`/`Gasto` (o `ingreso`/`gasto`)**

## Labels sugeridos
`bug` · `backend` · `validación de datos` · `prioridad: baja`

## Descripción

El campo `Tipo` de `Categoria` solo está limitado a `[StringLength(20)]`. El controlador copia el valor sin normalizar ni validar, de modo que se pueden persistir valores como `"ingreso"`, `"INGRESO"`, `"ahorro"` o `"123"`. El frontend y la lógica de presupuestos/movimientos asumen que el tipo es uno de los valores canónicos (`Ingreso`/`Gasto`), por lo que un valor incorrecto puede romper filtros, íconos o el cálculo de saldos.

Los tests unitarios construyen categorías válidas, por lo que no exponen el problema; no existe ninguna prueba de rechazo de `tipo` inválido.

## Código actual

**Archivo:** `Entities/Categoria.cs` (líneas 19–24)

```csharp
[Required]
[StringLength(20)]
public string Tipo { get; set; } = null!;
```

**Archivo:** `Controllers/CategoriasController.cs` → `Create` (líneas 33–41) y `Update` (líneas 43–54) copian `input.Tipo` sin validación.

## Pasos para reproducir

1. `POST /api/Categorias` con `{"nombre":"Mixta","tipo":"otra-cosa"}` + token válido.
2. **Resultado obtenido:** `201 Created` (se persiste `tipo: "otra-cosa"`).
   **Esperado:** `400 Bad Request` indicando que `tipo` debe ser `Ingreso` o `Gasto`.

## Impacto

- Datos inconsistentes que derivan en comportamientos impredecibles del frontend (categorías que no se muestran en la pestaña de ingresos ni de gastos, filtros vacíos, totales mal calculados).

## Corrección sugerida

Opción A — atributos de validación sobre la propiedad:

```csharp
[Required]
[RegularExpression("^(Ingreso|Gasto)$", ErrorMessage = "El tipo debe ser 'Ingreso' o 'Gasto'.")]
[StringLength(20)]
public string Tipo { get; set; } = null!;
```

Opción B — validación explícita en el controlador antes de guardar:

```csharp
if (categoria.Tipo is not ("Ingreso" or "Gasto"))
    return BadRequest(new { mensaje = "'tipo' debe ser 'Ingreso' o 'Gasto'." });
```

Y caso de regresión: `POST`/`PUT` con `tipo` inválido → `400`.

## Entorno verificado
- Fuente de `backend-develop.zip` (rama develop) · .NET 8
- Test unitario `CategoriasControllerTests`: no incluye casos de `tipo` inválido