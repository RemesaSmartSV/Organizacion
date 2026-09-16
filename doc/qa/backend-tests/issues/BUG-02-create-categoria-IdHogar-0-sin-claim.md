# BUG-02 — Create/Create de categoría graba IdHogar=0 si falta el claim `idHogar`

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Categorías] `POST /api/Categorias` persiste una categoría con `IdHogar = 0` cuando el token no trae el claim `idHogar` (datos huérfanos)** 

## Labels sugeridos
`bug` · `backend` · `integridad de datos` · `prioridad: media`

## Descripción

`GetIdHogar()` devuelve `0` si el claim `idHogar` falta o no es un entero válido. `Create` asigna ese valor directamente sin validarlo, por lo que **si un token válido pero sin el claim (o con malformación) llega al endpoint, se inserta una categoría con `IdHogar = 0`** que no pertenece a ningún hogar existente (o que colisiona con la fila del hogar `0` si existe). Lo mismo aplica de forma derivada a cualquier lógica de ruteo: esa categoría queda invisible para todos los hogares reales, generando datos huérfanos e inconsistencia.

El caso es marginal (el emisor JWT siempre incluye el claim), pero es una barrera de integridad que el backend debería cerrar: los tests unitarios inyectan siempre el claim, por lo que la rama con `GetIdHogar() == 0` queda sin cubrir.

## Código actual

**Archivo:** `Services/ClaimsPrincipalExtensions.cs` (líneas 10–11)

```csharp
public static int GetIdHogar(this ClaimsPrincipal user)
    => int.TryParse(user.FindFirstValue("idHogar"), out var id) ? id : 0;
```

**Archivo:** `Controllers/CategoriasController.cs` → `Create` (líneas 33–41)

```csharp
[HttpPost]
public async Task<ActionResult<Categoria>> Create([FromBody] Categoria categoria)
{
    categoria.IdCategoria = 0;
    categoria.IdHogar = User.GetIdHogar();   // ← puede ser 0 sin validación
    _db.Categorias.Add(categoria);
    await db.SaveChangesAsync();
    return CreatedAtAction(...);
}
```

## Pasos para reproducir

1. Emitir (o forjar en un cliente de prueba) un token JWT firmado **sin** el claim `idHogar`.
2. `POST /api/Categorias` con `{"nombre":"Huérfana","tipo":"Gasto"}` usando ese token.
3. **Resultado obtenido:** `201 Created` con `idHogar: 0` persistido.
   **Esperado:** `400 Bad Request`/`401 Unauthorized`, sin insertar.

## Impacto

- Filas con `IdHogar = 0` que quedan fuera del alcance de cualquier hogar (ni siquiera visibles por sus familiares).
- Riesgo de romper el filtro por hogar de `GetCategorias` (dichas filas nunca se listan, pero ensucian datos y pueden afectar agregados globales).

## Corrección sugerida

```csharp
[HttpPost]
public async Task<ActionResult<Categoria>> Create([FromBody] Categoria categoria)
{
    var idHogar = User.GetIdHogar();
    if (idHogar <= 0)
        return BadRequest(new { mensaje = "Sesión sin hogar válido" });

    categoria.IdCategoria = 0;
    categoria.IdHogar = idHogar;
    // ...
}
```

Y registro de caso: *"usuario autenticado sin claim idHogar intenta crear categoría → 400 y no se persiste nada"*.

## Entorno verificado
- Fuente de `backend-develop.zip` (rama develop) · .NET 8
- Extensión `ClaimsPrincipalExtensions.GetIdHogar` retorna `0` ante claim ausente/malformado
- Tests unitarios: no cubren la rama (siempre inyectan el claim)