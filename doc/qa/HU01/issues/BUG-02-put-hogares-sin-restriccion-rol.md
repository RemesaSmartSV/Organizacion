# BUG-02 — Cualquier Miembro puede renombrar el hogar (PUT /api/Hogares/{id} sin restricción de rol)

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Hogares] `PUT /api/Hogares/{id}` permite a un usuario con rol "Miembro" renombrar el hogar (falta `[Authorize(Roles="Admin")]`)**

## Labels sugeridos
`bug` · `backend` · `security/autorización` · `prioridad: media-alta`

## Descripción

El endpoint de edición de hogar **no restringe por rol**: cualquier usuario autenticado del hogar puede cambiar su nombre. El resto de operaciones de escritura sí lo exigen correctamente (`DELETE /api/Hogares/{id}` con `[Authorize(Roles="Admin")]`; `POST/PUT/DELETE` de `/api/Usuarios` igualmente). `Update` es el único que quedó abierto.

**Confirmado empíricamente (CP-15):** un usuario con rol `"Miembro"` recibió **204 No Content** al renombrar el hogar. Lo esperado según la especificación de HU-01 es **403 Forbidden**.

## Código actual

**Archivo:** `Controllers/HogaresController.cs` → método `Update` (líneas ~29–38)

```csharp
[HttpPut("{id}")]
public async Task<IActionResult> Update(int id, [FromBody] UpdateHogarRequest request)
{
    var hogar = await _db.Hogares.FindAsync(id);
    if (hogar is null || hogar.IdHogar != User.GetIdHogar())
        return NotFound();
    hogar.NombreFamiliar = request.NombreFamiliar;
    await _db.SaveChangesAsync();
    return NoContent();
}
```

Comparar con `Delete` en el mismo controlador, que sí lo hace bien:

```csharp
[HttpDelete("{id}")]
[Authorize(Roles = "Admin")]   // ← esta restricción falta en Update
public async Task<IActionResult> Delete(int id) { ... }
```

## Pasos para reproducir

1. Levantar el entorno: `docker compose up -d --build postgres_db backend_api`
2. Registrar un hogar + admin:
   ```bash
   curl -X POST http://localhost:8080/api/Auth/register \
     -H "Content-Type: application/json" \
     -d '{"nombre":"Carlos","correo":"carlos@demo.com","contrasena":"Demo1234!","nombreFamiliar":"Familia Demo"}'
   ```
3. Como Admin, agregar un miembro (usar el token del paso 2):
   ```bash
   curl -X POST http://localhost:8080/api/Usuarios \
     -H "Authorization: Bearer $TOKEN_ADMIN" -H "Content-Type: application/json" \
     -d '{"nombre":"Ana","correo":"ana@demo.com","contrasena":"Demo1234!","rol":"Miembro"}'
   ```
4. Iniciar sesión como Ana y renombrar el hogar con su token:
   ```bash
   curl -X PUT http://localhost:8080/api/Hogares/1 \
     -H "Authorization: Bearer $TOKEN_ANA" -H "Content-Type: application/json" \
     -d '{"nombreFamiliar":"Renombrado Por Miembro"}'
   ```
5. **Resultado obtenido:** `204 No Content` (el nombre queda cambiado).
   **Esperado:** `403 Forbidden`.

## Impacto

- Un miembro cualquiera puede alterar datos visibles por todo el hogar (vector menor de abuso, inconsistencia con el modelo de permisos del resto de la API).
- Riesgo de regresión si el frontend confía en que solo Admins ven la opción de editar.

## Corrección sugerida

```csharp
[HttpPut("{id}")]
[Authorize(Roles = "Admin")]        // ← añadir
public async Task<IActionResult> Update(...) { ... }
```

Y agregar/registrar caso de regresión: *"Miembro intenta renombrar hogar → 403"*.

## Entorno verificado
- Rama `develop` · .NET 8 · PostgreSQL 16 vía Docker Compose — 2026-08-24
- Caso de prueba asociado: **CP-15**
