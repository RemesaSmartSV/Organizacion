# SEC-05 — Campos de texto libre sin sanear y `Contenido` de tips sin límite de longitud

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Security][Media] La API persiste y devuelve texto de usuario sin sanear (riesgo de XSS almacenado en el frontend) y `EducacionFinanciera.Contenido` no tiene límite de longitud**

## Labels sugeridos
`security` · `xss` · `validacion` · `owasp-a03` · `prioridad: media`

## Descripción

El backend **no es el sumidero de XSS** (no sirve HTML: solo `AddControllers()` + `MapControllers()`, y el serializador JSON escapa `<`, `>`, `&` a `\u003C`… verificado). El problema es que **no hay ninguna defensa en profundidad**: todos los campos de texto libre aceptan HTML/JS tal cual y lo devuelven sin transformar.

Campos afectados (todos verificados en `backend/Entities/`):

| Campo | Límite de longitud | Convierte/valida contenido |
|-------|--------------------|--------------------------|
| `Movimiento.Descripcion` | 255 | ❌ |
| `Movimiento.OrigenEmisora` | 100 | ❌ |
| `Categoria.Nombre` | 50 | ❌ |
| `MetaAhorro.Titulo` | 100 | ❌ |
| `Usuario.Nombre` | 100 | ❌ |
| `Hogar.NombreFamiliar` | (sin límite en la entidad) | ❌ |
| **`EducacionFinanciera.Contenido`** | **sin ningún límite** | ❌ |

Evidencia de comportamiento actual (verificada con `Xss_LaDescripcionYElOrigenDeUnMovimientoSeGuardanYSeDevuelvenSinTransformar`):

```jsonc
// POST /api/Movimientos
{ "descripcion": "<script>alert('xss')</script>",
  "origenEmisora": "<img src=x onerror=alert(1)>" }
// GET /api/Movimientos  ->  devuelve los mismos strings, byte a byte
```

`EducacionFinanciera.Contenido` es el caso mas relevante porque no tiene `[StringLength]` ni `[MaxLength]` (a diferencia del resto): un Admin puede guardar contenido de tamaño arbitrario (abuso de almacenamiento, respuestas grandes, y superficie innecesaria para XSS almacenado si ese campo se renderiza como HTML — que es justo el caso de uso de los "tips financieros").

**Dónde se materializa el riesgo:** en el frontend (repo `RemesaSmartSV/frontend`, no auditado aquí). Si `Descripcion`/`Contenido` se pintan con `dangerouslySetInnerHTML`, `innerHTML` o Markdown sin escapar → XSS almacenado con robo del token del victimizado (el `Authorization: Bearer` viaja en cada request).

## Pasos para reproducir

```powershell
# 1. Registrar y loguearse para obtener token
$token = (Invoke-RestMethod http://localhost:8080/api/Auth/register -Method Post -ContentType "application/json" -Body (@{
  nombre="Ana"; correo="ana@demo-test.com"; contrasena="Demo1234!"; nombreFamiliar="Familia Ana" }).token

# 2. Crear categoría y movimiento con payload XSS
$cat = Invoke-RestMethod http://localhost:8080/api/Categorias -Method Post -Headers @{Authorization="Bearer $token"} -ContentType "application/json" -Body '{"nombre":"Comida","tipo":"Gasto"}'
Invoke-RestMethod http://localhost:8080/api/Movimientos -Method Post -Headers @{Authorization="Bearer $token"} -ContentType "application/json" -Body (@{
  idCategoria=$cat.idCategoria; monto=5; fecha="2026-09-27T00:00:00Z"; tipo="Gasto";
  descripcion="<script>alert(document.cookie)</script>"; origenEmisora="<img src=x onerror=alert(1)>" } | ConvertTo-Json) | Out-Null

# 3. El payload se persiste y vuelve intacto
(Invoke-RestMethod http://localhost:8080/api/Movimientos -Headers @{Authorization="Bearer $token"}) | Select-Object -First 1
```

Caso de longitud (tips, requiere rol Admin):
```powershell
$largo = "A" * 200000
Invoke-RestMethod http://localhost:8080/api/TipsFinancieros -Method Post -Headers @{Authorization="Bearer $token"} -ContentType "application/json" -Body (@{ idCategoria=1; titulo="T"; contenido=$largo } | ConvertTo-Json)
# 200 OK: se aceptan ~200 KB sin límite ni rechazo
```

## Comportamiento esperado

1. Los campos de texto se devuelven **sin** HTML ejecutable, o el frontend los renderiza solo como texto (contrato explícito y documentado).
2. Todo campo de texto tiene un límite de longitud razonable, incluido `EducacionFinanciera.Contenido`.
3. Si un campo es deliberadamente HTML rico (los tips podrían serlo), se sanea con una librería AllowList (ej. HtmlSanitizer) y se marca como tal.

## Causa probable y corrección sugerida

**Causa:** los DTOs se validan por longitud (`[StringLength]`) pero no por contenido, y `EducacionFinanciera.Contenido` se quedó sin anotación. `SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true` (`Program.cs:13`) tampoco ayuda a que el modelo valide más.

**Corrección:**
```csharp
// Entities/EducacionFinanciera.cs
[Required]
[StringLength(5000, MinimumLength = 10)]
public string Contenido { get; set; } = null!;
```
```csharp
// Si el contenido de los tips es HTML rico (decisión de producto):
using Ganss.Xss;
var htmlSano = HtmlSanitizer.Default.Sanitize(input.Contenido);
```
Además, en el **frontend** (equipo responsable, repo aparte):
- renderizar siempre como texto; **nunca** `dangerouslySetInnerHTML` con datos de la API;
- añadir CSP `default-src 'self'` en el origen que sirve el frontend (contraparte de SEC-03);
- si el token acaba en `localStorage` (típico con JWT), cualquier XSS pasa a ser robo de sesión → valorar cookie `HttpOnly` + token de refresco.

## Prueba automatizada asociada

`backend.Tests/SeguridadTests.cs`:
- `Xss_LaDescripcionYElOrigenDeUnMovimientoSeGuardanYSeDevuelvenSinTransformar` (documenta que el payload pasa intacto).
- `Vuln_SEC05_ElContenidoDeLosTipsNoTieneLimiteDeLongitudNiValidacionDeContenido` (falla al corregir).
- Positivos: `Xss_ElSerializadorJsonDeLaApiEscapaLosCaracteresHtmlDeLosCamposDeTexto`, `Xss_LosCamposDeTextoConLengthLimitanLoQueSePuedePersistirEnElPayload`.

## Entorno verificado
- `develop` · API .NET 8 · EF Core InMemory para la verificación automatizada
- Revisión estática + 42 casos xUnit — 2026-09-27
- Casos: CP-S-28, CP-S-32
- Relacionado: SEC-03 (CSP es la defensa principal y va en el frontend), SEC-08 (menos superficie de depuración)
- ⚠️ Pendiente de verificación en el repo `RemesaSmartSV/frontend`: método de render de `descripcion`/`contenido` y si el token se guarda en `localStorage`
