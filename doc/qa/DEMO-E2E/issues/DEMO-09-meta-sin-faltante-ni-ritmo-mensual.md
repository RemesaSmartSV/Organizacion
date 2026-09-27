# DEMO-09 — `MetaAhorro` no expone el faltante ni el ritmo mensual sugerido

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Metas] La entidad `MetaAhorro` no tiene campos de progreso, faltante ni ritmo mensual: los tres cálculos que promete el guion los hace el frontend**

## Labels sugeridos
`feature` · `metas` · `api-contract` · `prioridad: media`

## Descripción

El guion promete tres cosas para la meta de ahorro:

> Cada meta tiene **monto objetivo, fecha límite y aportes registrados**. La app calcula el progreso, lo que
> falta y **el ritmo mensual sugerido** para llegar.

Lo verificado en la ejecución:

| Promesa | Estado en la API | Check |
|---|---|---|
| Monto objetivo | ✅ `montoObjetivo` | `CP-D30` verde |
| Fecha límite | ✅ `fechaLimite` | `CP-D30` verde |
| Aportes registrados | ✅ `GET /api/Aportes?metaId=` | `CP-D32` verde |
| El aporte actualiza solo `montoActual` | ✅ funciona | `CP-D33` verde |
| El estado cambia solo al completar | ✅ `"Completada"` al llegar al objetivo | `CP-D34` verde |
| **Progreso (porcentaje)** | ❌ no existe | `CP-D35` rojo |
| **Lo que falta** | ❌ no existe | `CP-D35` rojo |
| **Ritmo mensual sugerido** | ❌ no existe | `CP-D35` rojo |

La parte que sí es "mágica" y automática —el monto actual y el estado— **funciona y está probada**. Lo que falta
es exactamente la parte que el guion usa como argumento de venta del módulo:

> No es "hay que ahorrar": es "faltan $1,200, faltan cuatro meses, aparta $300 al mes". **Eso sí se cumple.**

Ese "eso sí se cumple" hoy depende de que el cliente haga la cuenta.

## Evidencia

Check `CP-D35`:

```
[FAIL] CP-D35  La API entrega "lo que falta" y el ritmo mensual sugerido
         esperado: campos de faltante y de aporte mensual
         obtenido: solo: idMeta,idHogar,titulo,montoObjetivo,montoActual,fechaLimite,estado
```

Campos reales devueltos por `GET /api/MetasAhorro/{id}`:

```
idMeta, idHogar, titulo, montoObjetivo, montoActual, fechaLimite, estado
```

Contraste con lo que sí funciona, mismo endpoint tras dos aportes ($300 + $1,700):

```
montoActual=2000.00, Estado='Completada'
```

## Pasos para reproducir

1. `POST /api/MetasAhorro` con `montoObjetivo: 2000`, `fechaLimite` a 6 meses.
2. `GET /api/MetasAhorro/{id}` → solo `montoObjetivo`, `montoActual`, `fechaLimite`, `estado`.
3. El 100% de avance, los $0 que faltan y el $0/mes de ritmo se calculan a mano.

## Comportamiento esperado

Calcular los tres en el servidor y devolverlos, con `decimal` y con las reglas de redondeo definidas por el
equipo (recomendado: redondear a centavos y.ceil() el aporte mensual, para que la suma de las cuotas cubra el
objetivo):

```csharp
public class MetaAhorroDto
{
    public int IdMeta { get; set; }
    public string Titulo { get; set; }
    public decimal MontoObjetivo { get; set; }
    public decimal MontoActual { get; set; }
    public DateTime FechaLimite { get; set; }
    public string Estado { get; set; }
    public decimal Faltante { get; set; }              // nuevo
    public decimal PorcentajeAvance { get; set; }      // nuevo
    public int MesesRestantes { get; set; }            // nuevo
    public decimal RitmoMensualSugerido { get; set; }   // nuevo
}
```

Reglas de borde que hay que decidir explícitamente (hoy nadie las decidió porque el cálculo no existe):

- `Faltante = max(0, MontoObjetivo − MontoActual)`.
- `MesesRestantes` cuando la fecha límite ya pasó: ¿0, o negativo? Si es 0, la app debería avisar "meta vencida".
- `RitmoMensualSugerido` cuando `Faltante = 0`: hoy sería `0` o `null`. La `DEMO_GUIDE` promete "el ritmo
  mensual se ve en 0", lo que conviene confirmar.
- `Estado` es texto libre `[StringLength(20)]` con dos valores en uso (`"En progreso"`, `"Completada"`): mismo
  patrón de lista blanca de `DEMO-05`, y además `PUT /api/MetasAhorro/{id}` **permite escribir el estado a
  mano**, con lo que un cliente puede dejar una meta en `"Completada"` sin haber llegado al objetivo, o
  tumbar una meta completa a `"En progreso"`. AportesController es el único que escribe ese campo con lógica.

## Causa

`Entities/MetaAhorro.cs` no tiene los campos derivados y `MetasAhorroController` no hace ningún cálculo: es
CRUD más la actualización automática del aporte en `AportesController` (líneas 37-42).

## Impacto

- El argumento de valor agregado 7.3 del guion ("el ahorro deja de ser un deseo y se vuelve un plan con número")
  no tiene respaldo en la API.
- El cálculo del ritmo mensual es aritmética de dinero sin pruebas y duplicada en el cliente.
- `Estado` escribible a mano permite estados inconsistentes con los aportes.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · 2026-09-27
Caso de prueba asociado: **CP-D30** a **CP-D35** (de `Ejecutar_Demo_E2E.ps1`)
