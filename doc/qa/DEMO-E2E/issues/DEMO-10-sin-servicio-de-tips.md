# DEMO-10 — No hay servicio de tips: `EducacionFinanciera` depende de una `Categoria` por hogar

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Educación Financiera] El contenido es global pero cada tip apunta a una `Categoria`, que es por hogar: no hay forma de crear un tip sin inventar una categoría de una familia**

## Labels sugeridos
`bug` · `educacion-financiera` · `modelo` · `prioridad: media`

## Descripción

`EducacionFinanciera` es contenido **global y de solo lectura** (el guion: *"esta sección es de solo lectura"*,
*"No damos clases de finanzas"*). Sin embargo, su modelo la ata a `Categorias`, que es una tabla **por hogar**:

```csharp
public class EducacionFinanciera
{
    [Key] public int IdTip { get; set; }
    [Required] public int IdCategoria { get; set; }   // <-- FK a Categoria, que tiene IdHogar
    [Required, StringLength(150)] public string Titulo { get; set; }
    [Required] public string Contenido { get; set; }
    [ForeignKey("IdCategoria")] public virtual Categoria Categoria { get; set; }
}
```

Y como `POST /api/TipsFinancieros` es `Admin` y valida la categoría:

```csharp
var categoria = await _db.Categorias.FindAsync(tip.IdCategoria);
if (categoria is null) return BadRequest(new { message = "La categoría no existe." });
```

Un `Admin` de una familia **no puede crear un tip si no crea antes una `Categoria` en su propio hogar** (por
ejemplo "Ahorro"), y ese tip queda visible para **todas** las familias. Es decir: el contenido global depende
de datos de una familia concreta, y quien carga contenido decide qué tema. Además, el `IdHogar` de esa categoría es
irrelevante para el tip pero obligatorio para crearlo.

## Evidencia

Firma del método (`TipsFinancierosController.cs:30-42`):

```csharp
[HttpPost]
[Authorize(Roles = "Admin")]
public async Task<ActionResult<EducacionFinanciera>> Create([FromBody] EducacionFinanciera tip)
{
    var categoria = await _db.Categorias.FindAsync(tip.IdCategoria);
    if (categoria is null)
        return BadRequest(new { message = "La categoría no existe." });
    ...
}
```

Comprobación sobre la base limpia: `Categorias = 0` y `TipsFinancieros = 0`. Con cero categorías no se puede
crear ni el primer tip. Encadenado con [DEMO-02](DEMO-02-educacion-financiera-sin-contenido-sembrado.md), el
resultado es que la sección está **doblemente bloqueada**: no hay contenido y, aunque lo hubiera, no hay forma
limpia de cargarlo.

## Pasos para reproducir

1. Registrarse (se crea el hogar y el Admin).
2. `POST /api/TipsFinancieros` con `{ "idCategoria": 1, "titulo": "Ahorra antes de gastar", "contenido": "..." }`
   → `400 "La categoría no existe."`
3. Crear primero una `Categoria` en el hogar y volver a intentar → `201`, y el tip queda global.

## Comportamiento esperado

Que la relación con `Categoria` sea opcional y representativa de "a qué tema se parece este tip", sin ser un
requisito de carga:

```csharp
// Opción A — desacoplar por completo (recomendada)
public class EducacionFinanciera
{
    [Key] public int IdTip { get; set; }
    [Required, StringLength(150)] public string Titulo { get; set; }
    [Required] public string Contenido { get; set; }
    [StringLength(50)] public string? Tema { get; set; }   // texto libre: "Ahorro", "Transporte", …
    [StringLength(50)] public string? Icono { get; set; }
}
```

Con eso, el contenido se puede sembrar en una migración (resolviendo `DEMO-02`) sin crear hogares de prueba.

Alternativa si se quiere conservar el vínculo: usar una tabla de **categorías de contenido global**, separada de
las categorías de gastos del hogar, en lugar de apuntar a `Categorias`.

Además conviene bajar el permiso: hoy `POST/PUT/DELETE` de tips es `Admin` de una familia, lo que significa
que **cualquier familia que se registre puede modificar el contenido global que ve el resto**
(`PUT /api/TipsFinancieros/{id}` no comprueba el hogar). Es un problema de autorización de contenido global
resuelto por accidente, no por diseño.

## Causa

El modelo de `EducacionFinanciera` se diseñó como si el contenido fuera por hogar (de ahí la FK), pero el
endpoint de lectura lo trata como global:

```csharp
[HttpGet, AllowAnonymous]
public async Task<ActionResult<IEnumerable<EducacionFinanciera>>> GetTips()
    => Ok(await _db.TipsFinancieros.OrderBy(t => t.Titulo).ToListAsync());   // sin filtro por IdHogar
```

## Impacto

- No se puede sembrar contenido de educación financiera de forma limpia (bloquea `DEMO-02`).
- Cualquier Admin puede alterar el contenido global; no hay separación entre "contenido del producto" y
  "datos del hogar".
- La promesa de "tip relacionado con la actividad de la familia" no es implementable con este modelo
  (ver `CP-D37` en el README de esta entrega): no hay campo que describa a qué actividad aplica el tip, ni
  endpoint que lo recomiende.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · 2026-09-27
Caso de prueba asociado: **CP-D02**, **CP-D36**, **CP-D37** (de `Ejecutar_Demo_E2E.ps1`)
