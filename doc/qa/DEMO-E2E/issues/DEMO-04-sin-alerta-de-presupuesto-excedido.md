# DEMO-04 — La API no entrega la alerta de presupuesto excedido

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Presupuestos] Ningún endpoint, campo ni código HTTP indica que un presupuesto fue excedido: el momento clave de la demo depende de que el frontend lo detecte por su cuenta**

## Labels sugeridos
`feature` · `presupuestos` · `demo` · `prioridad: alta`

## Descripción

El guion de la demo marca el exceso del presupuesto como el momento fuerte de la presentación:

> 8. **Agregar un gasto de $200 más** → la barra se pasa y **aparece la alerta**.
>    *Este es el momento clave de la demo: hacer pausa aquí.*

Lo verificado es que **los datos sí permiten saber que el presupuesto se excedió** (el gasto acumulado de
$320 contra un límite de $300 se ve sin problema al cruzar `/api/Movimientos` con `/api/Presupuestos`), pero
**la API no expone nada que lo indique**:

- `Presupuesto` solo tiene `montoLimite` y `mesAnio` (ver `DEMO-06`).
- No existe ningún campo `excedido`, `porcentajeConsumido`, `montoGastado` o `nivelAlerta`.
- No existe ningún endpoint tipo `/api/Presupuestos/{id}/alerta` ni `/api/Alertas`.
- No se devuelve ningún código o cabecera que sinalice el exceso (por ejemplo `X-Budget-Exceeded`).

En la práctica, el "aparece la alerta" del paso 8 es un calculo cruzado en el frontend. Si esa lógica no está
implementada en el cliente, el paso más importante de la demo pasa sin que el jurado vea nada — y sin ningún
error visible que lo delate.

## Evidencia

Check `CP-D28` (los datos están bien):

```
[PASO] CP-D28  (datos)  El consumo acumulado supera el limite del presupuesto
         esperado: gasto=320 > limite=300 -> 106.67% | obtenido: gasto=320.00 -> 106.67%
```

Check `CP-D29` (la API no lo entrega):

```
[FAIL] CP-D29  La API entrega la alerta de presupuesto excedido
         esperado: campo o endpoint de alerta de exceso
         obtenido: ninguno: la respuesta es el presupuesto tal cual
```

Campos reales devueltos por `GET /api/Presupuestos/{id}`:

```
idPresupuesto, idHogar, idCategoria, montoLimite, mesAnio
```

Es decir: para que la barra pueda pintar el 40% en verde, el 90% en amarillo y el 107% en rojo, el frontend
tiene que traer él los movimientos del período, agruparlos por categoría y cruzar los tres umbrales que fija la
`DEMO_GUIDE` (§7.3).

## Pasos para reproducir

1. Levantar el entorno y crear una familia (`POST /api/Auth/register`).
2. Crear una categoría de gasto y un presupuesto de $300 para el mes actual.
3. Registrar un gasto de $320 en esa categoría.
4. `GET /api/Presupuestos/{id}` → el presupuesto vuelve idéntico, sin ningún indicador de exceso.
5. Revisar `GET /swagger/index.html` → no hay ningún endpoint de alertas.

## Comportamiento esperado

Que el el endpoint de presupuestos exponga el consumo y el nivel de alerta ya calculado, para que el frontend no
tenga que reimplementar la regla de negocio en tres sitios (tarjeta del dashboard, página de presupuestos,
alertas). Opciones:

```csharp
// Endpoint de listado: cada presupuesto vuelve con su consumo del período
public class PresupuestoDto
{
    public int IdPresupuesto { get; set; }
    public int IdCategoria { get; set; }
    public decimal MontoLimite { get; set; }
    public DateTime MesAnio { get; set; }
    public decimal MontoGastado { get; set; }              // nuevo
    public decimal PorcentajeConsumido { get; set; }       // nuevo
    public string NivelAlerta { get; set; }                 // nuevo: "OK" | "Aviso" | "Excedido"
}
```

Los umbrales (70% / 90%) quedan así en **un solo lugar**, el backend, y no duplicados en el cliente.

⚠️ A resolver junto: los movimientos se filtran por `tipo` como texto libre y son **sensibles a mayúsculas**
(ver `DEMO-05` y `FP-05` en [`FILTROS-PAGINACION`](../../FILTROS-PAGINACION/README.md)). Si el cálculo de
`MontoGastado` se basa en `tipo == "Gasto"`, un movimiento guardado como `"gasto"` no se contaría y el
presupuesto aparecería sin gastar. Conviene resolver primero la lista blanca de `Tipo`.

## Causa

`PresupuestosController` solo hace CRUD + filtro por período. No hay ninguna capa de negocio que compare
presupuestos contra movimientos: el módulo no tiene servicio.

## Impacto

- El paso 8 de la demo, señalado como el momento clave, no tiene soporte en la API.
- La "alerta en el momento en que se pasa" (argumento de valor agregado 7.2 del guion) no está respaldada por
  nada en el backend.
- La DEMO_GUIDE (§7.3) especifica los umbrales de color, lo que sugiere que la regla vive en el frontend:
  reglas de negocio de dinero duplicadas y potencialmente divergentes.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · 2026-09-27
Caso de prueba asociado: **CP-D28** y **CP-D29** (de `Ejecutar_Demo_E2E.ps1`)
