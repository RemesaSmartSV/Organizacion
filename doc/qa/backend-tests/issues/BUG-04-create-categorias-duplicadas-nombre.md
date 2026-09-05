# BUG-04 — Permite crear categorías con el mismo nombre dentro del mismo hogar

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Categorías] `POST /api/Categorias` no impide nombres duplicados en un mismo hogar (se crean dos filas idénticas)**

## Labels sugeridos
`bug` · `backend` · `usabilidad/datos` · `prioridad: baja`

## Descripción

No existe ninguna restricción de unicidad sobre `(IdHogar, Nombre)` ni validación previa en el controlador: basta llamar dos veces a `POST /api/Categorias` con el mismo nombre para obtener dos categorías idénticas. A la larga esto genera filas redundantes que confunden al usuario y fragmentan la suma de gastos/ingresos (una misma categoría aparece duplicada en la UI con saldos partidos).

El test unitario `Create_AsignaHogarDelUsuarioYPersiste` solo verifica la creación de una categoría; no cubre la duplicidad.

## Código actual

**Archivo:** `Controllers/CategoriasController.cs` → `Create` (líneas 33–41)

```csharp
[HttpPost]
public async Task<ActionResult<Categoria>> Create([FromBody] Categoria categoria)
{
    categoria.IdCategoria = 0;
    categoria.IdHogar = User.GetIdHogar();
    _db.Categorias.Add(categoria);
    await _db.SaveChangesAsync();   // ← guarda sin comprobar homónimos del hogar
    return CreatedAtAction(nameof(GetCategoria), new { id = categoria.IdCategoria }, categoria);
}
```

## Pasos para reproducir

1. `POST /api/Categorias` con `{"nombre":"Alimentación","tipo":"Gasto"}`.
2. Repetir el mismo `POST` con el mismo nombre.
3. **Resultado obtenido:** dos `201 Created` y dos filas en `Categorias` con `IdHogar` y `Nombre` iguales (distinto `IdCategoria`).
   **Esperado:** `409 Conflict` (o `400`) indicando que la categoría ya existe en el hogar.

## Impacto

- Categorías duplicadas en la UI y agregados de presupuesto/movimientos inflados o fragmentados.
- Re-trabajo manual para el usuario (renombrar/borrar duplicados, reasignar movimientos).

## Corrección sugerida

```csharp
// Antes de guardar:
var duplicada = await _db.Categorias.AnyAsync(c =>
    c.IdHogar == categoria.IdHogar &&
    c.Nombre.ToLower() == categoria.Nombre.ToLower());
if (duplicada)
    return Conflict(new { mensaje = "Ya existe una categoría con ese nombre" });
```

Opcionalmente, índice único a nivel de base:

```csharp
modelBuilder.Entity<Categoria>()
    .HasIndex(c => new { c.IdHogar, c.Nombre })
    .IsUnique();
```

(implica nueva migración) y manejar el `DbUpdateException` resultante como `409`.

## Entorno verificado
- Fuente de `backend-develop.zip` (rama develop) · .NET 8
- Sin índice único `(IdHogar, Nombre)` en la migración `20260811193629_InitialCreate`
- Test unitario `CategoriasControllerTests`: no cubre duplicados