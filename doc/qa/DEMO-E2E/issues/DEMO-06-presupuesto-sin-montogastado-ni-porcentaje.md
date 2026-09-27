# DEMO-06 — `Presupuesto` no expone el consumo ni el porcentaje

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Presupuestos] La entidad `Presupuesto` solo tiene `montoLimite` y `mesAnio`: el 40% consumido y el color de la barra los tiene que calcular el frontend**

## Labels sugeridos
`feature` · `presupuestos` · `api-contract` · `prioridad: media`

## Descripción

El paso 7 de la demo es crear un presupuesto de $300 en alimentación y mostrar que *"la barra de progreso"* marca
40% consumido. La aritmética es correcta y los datos están ahí, pero **la respuesta de la API no contiene
ningún dato de consumo**: ni monto gastado, ni porcentaje, ni nivel de alerta.

Esto obliga al frontend a traer todos los movimientos del período, filtrar por categoría, agrupar por `tipo` y
comparar contra el límite — y a hacerlo **una vez por cada fila de la tabla de presupuestos** (un N+1 de
llamadas o un filtrado completo en cliente). Los umbrales de color (70% verde / 90% amarillo / 100% rojo) que
la `DEMO_GUIDE` describe como comportamiento del producto quedan entonces **duplicados en el cliente**, sin
ningún contrato que los respalde.

## Evidencia

Check `CP-D24` (la aritmética da bien) y `CP-D25` (la API no lo entrega):

```
[FAIL] CP-D25  La API entrega el consumo del presupuesto (montoGastado / porcentaje)
         esperado: campo de consumo o porcentaje en la respuesta
         obtenido: solo: idPresupuesto,idHogar,idCategoria,montoLimite,mesAnio
```

Campos reales de `GET /api/Presupuestos/{id}`:

```
idPresupuesto, idHogar, idCategoria, montoLimite, mesAnio
```

Campos reales de `GET /api/Presupuestos?anio=2026&mes=9` (mismo conjunto, sin join ni agregado).

## Pasos para reproducir

1. Crear una categoría de gasto y un presupuesto de $300 para el mes actual.
2. Registrar un gasto de $120 en esa categoría.
3. `GET /api/Presupuestos/{id}` → devuelve `montoLimite: 300.00` y nada más.
4. El 40% se obtiene únicamente cruzando a mano con `GET /api/Movimientos?categoriaId={id}`.

## Comportamiento esperado

Que el listado de presupuestos devuelva el consumo ya calculado, idealmente con un DTO (ver la propuesta de
`DEMO-04`, que resuelve ambas carencias con un solo endpoint):

```csharp
// GET /api/Presupuestos?anio=2026&mes=9
[
  {
    "idPresupuesto": 1,
    "idCategoria": 54,
    "montoLimite": 300.00,
    "mesAnio": "2026-09-01T00:00:00Z",
    "montoGastado": 320.00,        // nuevo
    "porcentajeConsumido": 106.67, // nuevo
    "nivelAlerta": "Excedido"      // nuevo
  }
]
```

## Causa

`Entities/Presupuesto.cs` no tiene ningún campo de consumo, y `PresupuestosController.GetPresupuestos` (líneas
19-27) es un `Select` simple sobre `_db.Presupuestos`, sin `Include` ni agregación contra `Movimientos`.

## Relación

Es la otra mitad de [DEMO-04](DEMO-04-sin-alerta-de-presupuesto-excedido.md): sin `montoGastado` no hay barra
y sin `nivelAlerta` no hay alerta. **Se resuelven juntos.**

## Impacto

- La barra de progreso del paso 7 de la demo no se puede pintar a partir de la respuesta de la API.
- Los umbrales de negocio de un producto financiero viven en el cliente, sin pruebas.
- Con el volumen de datos del `[PERF]` (1.000+ movimientos), el filtrado por parte del cliente es también un
  problema de rendimiento en móvil de gama media, que es el usuario objetivo del proyecto.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · 2026-09-27
Caso de prueba asociado: **CP-D25** (de `Ejecutar_Demo_E2E.ps1`)
