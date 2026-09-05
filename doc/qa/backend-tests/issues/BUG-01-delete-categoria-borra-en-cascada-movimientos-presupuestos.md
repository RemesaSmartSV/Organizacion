# BUG-01 — DELETE de categoría borra en cascada los movimientos y presupuestos asociados

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Categorías] `DELETE /api/Categorias/{id}` elimina en cascada todos los `Movimientos` y `Presupuestos` de la categoría (pérdida de datos del hogar)**

## Labels sugeridos
`bug` · `backend` · `data-loss` · `prioridad: alta`

## Descripción

El endpoint `Delete` del `CategoriasController` borra la categoría sin verificar si está en uso. En PostgreSQL las claves foráneas `FK_Movimientos_Categorias_IdCategoria` y `FK_Presupuestos_Categorias_IdCategoria` están definidas con **`ON DELETE CASCADE`** (migración `20260811193629_InitialCreate`, líneas 118 y 192).

Consecuencia: **borrar una categoría que tiene movimientos o presupuestos elimina silenciosamente todo el historial financiero del hogar asociado a esa categoría** (transacciones, aportes presupuestados, etc.). Un simple error de clic (o un borrado por confusión) resulta en pérdida irrecuperable de datos.

El test unitario actual `Delete_DeMismoHogar_EliminaYDevuelveNoContent` no detecta el problema porque `InMemory` no impone ni reproduce el comportamiento real de las restricciones `ON DELETE` del PostgreSQL.

## Código actual

**Archivo:** `Controllers/CategoriasController.cs` → método `Delete` (líneas 56–65)

```csharp
[HttpDelete("{id}")]
public async Task<IActionResult> Delete(int id)
{
    var categoria = await _db.Categorias.FirstOrDefaultAsync(c => c.IdCategoria == id && c.IdHogar == User.GetIdHogar());
    if (categoria is null)
        return NotFound();
    _db.Categorias.Remove(categoria);          // ← no valida referencias
    await _db.SaveChangesAsync();
    return NoContent();
}
```

Migración que define el cascada:

```csharp
name: "FK_Presupuestos_Categorias_IdCategoria",
onDelete: ReferentialAction.Cascade);   // línea 118

name: "FK_Movimientos_Categorias_IdCategoria",
onDelete: ReferentialAction.Cascade);   // línea 192
```

## Pasos para reproducir

1. Levantar el entorno: `docker compose up -d --build postgres_db backend_api`
2. Registrar hogar + admin y crear una categoría de "Transporte".
3. Registrar un movimiento con `idCategoria` = categoría creada.
4. Ejecutar `DELETE /api/Categorias/{id}` con el token de admin.
5. **Resultado obtenido:** `204 No Content` y el movimiento del paso 3 **desaparece** de la base (cascada).
   **Esperado:** `409 Conflict` (o borrado lógico/desmarcado), conservando los datos asociados.

## Impacto

- Pérdida de datos financieros del hogar (historial de movimientos y presupuestos) sin confirmación ni aviso.
- Inconsistencia con el modelo de permisos y la expectativa de borrado "suave" típica de apps de finanzas personales.

## Causa probable y corrección sugerida

**Archivo:** `Controllers/CategoriasController.cs` → `Delete`.

Opciones (cualquiera):

```csharp
// Opción A — validar que no esté referenciada antes de borrar
if (await _db.Movimientos.AnyAsync(m => m.IdCategoria == id && m.IdHogar == User.GetIdHogar())
    || await _db.Presupuestos.AnyAsync(p => p.IdCategoria == id && p.IdHogar == User.GetIdHogar()))
    return Conflict(new { mensaje = "La categoría tiene movimientos o presupuestos asociados" });

// Opción B — cambiar el DeleteBehavior a Restrict/NoAction en el modelo/migración
//   (implica nueva migración para los FK de Movimientos y Presupuestos)
```

Y agregar caso de regresión: *"borrar categoría con movimientos asociados → 409 y los movimientos permanecen"*.

## Entorno verificado
- Fuente de `backend-develop.zip` (rama develop) · .NET 8 · Migración `20260811193629_InitialCreate`
- FK `Movimientos→Categorias` y `Presupuestos→Categorias` con `ON DELETE CASCADE`
- Test unitario actual: **no detecta** (InMemory no replica la cascada)