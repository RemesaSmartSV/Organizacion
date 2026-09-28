# SEC-06 — El campo `Rol` es texto libre sin lista blanca

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Media] `Rol` se persiste tal cual desde el cuerpo de la petición (sin lista blanca `Admin`/`Miembro`): un typo deja al usuario sin permisos y un valor inventado rompe el modelo de autorización**

## Labels sugeridos
`security` · `autorizacion` · `validacion` · `owasp-a04` · `prioridad: media`

## Descripción

El rol es una **cadena libre** en los DTOs de entrada y se guarda en la BD sin validar contra la lista de roles válidos:

`backend/DTOs/AuthDtos.cs`
```csharp
public record AddMemberRequest(..., string? Rol);
public record UpdateUsuarioRequest(string? Nombre, string? Rol);
```

`backend/Controllers/UsuariosController.cs:41`
```csharp
Rol = string.IsNullOrWhiteSpace(request.Rol) ? "Miembro" : request.Rol,
```

`backend/Controllers/UsuariosController.cs:61`
```csharp
usuario.Rol = request.Rol;
```

Como la autorización se decide por comparación de rol (`[Authorize(Roles = "Admin")]` → compara el claim con el string exacto), cualquier valor que no sea exactamente `Admin` **degrada al usuario a sin permisos** y cualquier otro valor crea un "rol fantasma" que el código no contempla:

- `Rol = "admin"` (minúscula) → el usuario **no puede** crear/borrar miembros, pero en la UI puede verse como ADMIN → fallos.support inexplicables.
- `Rol = "Admin "` (espacio final), `"Miembro "` → mismo efecto, invisible a simple vista.
- `Rol = "SuperAdmin"`, `"Root"`, `"admin,Admin"` → rol persistido que no corresponde a ningún permiso; en el futuro, si alguien añade `[Authorize(Roles="SuperAdmin")]` o un `switch` por rol, aparecen rutas de escalación no previstas.
- `Rol = ""` en `Update` → no se aplica (hay `IsNullOrWhiteSpace`), pero `Rol = "   x"` sí.

Verificado empíricamente: `PUT /api/Usuarios/{id}` con `{"rol":"SuperAdmin"}` persiste `"SuperAdmin"` (prueba `Vuln_SEC06_UpdateUsuarioPersisteUnRolFueraDeLaListaAdminMiembro`), y `POST /api/Usuarios` con `{"rol":"Root"}` crea el usuario con ese rol (prueba `Vuln_SEC06_AddMemberAceptaElRolIndicadoSinValidarContraLaListaAdminMiembro`).

**Matiz de severidad:** ambos endpoints exigen `[Authorize(Roles = "Admin")]`, así que un Miembro no puede auto-otorgarse nada → no hay escalada de privilegios directa hoy. El riesgo es de **integridad del modelo de autorización** (y de disponibilidad si el rol inventado colisiona con un permiso futuro).

## Pasos para reproducir

```powershell
$token = (Invoke-RestMethod http://localhost:8080/api/Auth/login -Method Post -ContentType "application/json" -Body '{"correo":"carlos@demo-test.com","contrasena":"Demo1234!"}').token
$h = @{Authorization="Bearer $token"}

# Crear miembro con rol inexistente
$nuevo = Invoke-RestMethod http://localhost:8080/api/Usuarios -Method Post -Headers $h -ContentType "application/json" -Body '{"nombre":"Luis","correo":"luis@demo-test.com","contrasena":"Demo1234!","rol":"SuperAdmin"}'
$nuevo.rol      # -> "SuperAdmin"

# Con ese rol el usuario no puede ejecutar ni la accion mas basica de admin
Invoke-RestMethod http://localhost:8080/api/Usuarios -Method Post -Headers @{Authorization="Bearer $((Invoke-RestMethod http://localhost:8080/api/Auth/login -Method Post -ContentType 'application/json' -Body '{"correo":"luis@demo-test.com","contrasena":"Demo1234!"}').token)"} -ContentType "application/json" -Body '{"nombre":"X","correo":"x@demo-test.com","contrasena":"Demo1234!"}'
# -> 403 Forbidden
```

## Comportamiento esperado

1. Solo se aceptan `Admin` y `Miembro` (case-insensitive si se decide así, pero normalizado a un único valor canónico).
2. Cualquier otro valor → `400 Bad Request` con mensaje claro, sin persistir nada.
3. Un Admin no puede degradarse a sí mismo ni dejar el hogar sin ningún Admin (evitar bloqueo de gestión).

## Causa probable y corrección sugerida

**Causa:** el rol se trata como `string` libre en vez de como enum/constantes validadas. Mismo patrón ya reportado para `Categoria.Tipo` en [BUG-03](../../backend-tests/issues/BUG-03-categorias-sin-validacion-tipo.md) → conviene resolver ambos con la misma técnica.

**Corrección:**
```csharp
// DTOs/AuthDtos.cs
public static class Roles
{
    public const string Admin = "Admin";
    public const string Miembro = "Miembro";
    public static readonly string[] Todos = [Admin, Miembro];

    public static bool EsValido(string? rol)
        => rol is not null && Todos.Contains(rol.Trim(), StringComparer.OrdinalIgnoreCase);

    public static string? Canonicalizar(string? rol)
        => EsValido(rol) ? (rol!.Trim().Equals(Admin, StringComparison.OrdinalIgnoreCase) ? Admin : Miembro) : null;
}
```
```csharp
// UsuariosController.Update -> normalizar y validar antes de tocar la BD
if (!string.IsNullOrWhiteSpace(request.Rol))
{
    var rolCanonico = Roles.Canonicalizar(request.Rol);
    if (rolCanonico is null)
        return BadRequest(new { message = "Rol inválido. Valores permitidos: Admin, Miembro." });
    usuario.Rol = rolCanonico;
}
```
Como mejora de fondo: reemplazar `string Rol` por un enum mapeado en la BD y convertir `Rol` del claim con el mismo enum, de modo que el sistema no pueda contener roles fuera del dominio.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs` → `Vuln_SEC06_UpdateUsuarioPersisteUnRolFueraDeLaListaAdminMiembro` y `Vuln_SEC06_AddMemberAceptaElRolIndicadoSinValidarContraLaListaAdminMiembro` (fallan al corregir).

## Entorno verificado
- `develop` · API .NET 8 + EF Core InMemory
- Revisión estática + 42 casos xUnit — 2026-09-27
- Casos: CP-S-26, CP-S-27 (más el control positivo CP-S-25: un `Miembro` recibe `403` en `POST /api/Usuarios`)
- Relacionado: BUG-03 (`Categoria.Tipo` sin validación, mismo patrón), BUG-02 (`PUT /api/Hogares` sin restricción de rol)
