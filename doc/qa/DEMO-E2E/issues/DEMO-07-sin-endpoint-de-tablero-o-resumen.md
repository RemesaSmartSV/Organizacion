# DEMO-07 — No hay endpoint de tablero o resumen

> Copiar desde aquí hacia arriba como **título** del issue y el resto como descripción.

---

## Título
**[Tablero] No existe ningún endpoint de resumen: los KPIs y las gráficas del dashboard se calculan descargando todos los movimientos al cliente**

## Labels sugeridos
`feature` · `dashboard` · `api-contract` · `prioridad: media`

## Descripción

El paso 6 de la demo es mostrar el tablero con "el flujo, la distribución del gasto y el saldo", y el guion lo
vende como el valor central: *"Eso es lo que permite pasar de 'sentimos que no alcanza' a 'tenemos el número'*.
La API expone 9 controladores (`Auth`, `Hogares`, `Usuarios`, `Categorias`, `Movimientos`, `Presupuestos`,
`MetasAhorro`, `Aportes`, `TipsFinancieros`) y **ninguno devuelve un agregado**: no hay `DashboardController`,
ni `/api/Resumen`, ni `/api/Tablero`.

Verificado en la ejecución: los números del guion **sí son derivables** desde `GET /api/Movimientos` sin error
aritmético ni de redondeo (check `CP-D20`: ingresos 400, gastos 120, saldo 280, montos con 2 decimales
exactos). Lo que no existe es el endpoint que lo calcule.

Consecuencia práctica: la "gráfica de barras: Ingresos vs Gastos por mes (últimos 6 meses)" de la
`DEMO_GUIDE` y la "gráfica circular: Distribución de Gastos por categoría" obligan al cliente a traer **todos**
los movimientos históricos y agruparlos en memoria.

## Evidencia

```
[FAIL] CP-D22  (relacionado) La API distingue la remesa de un ingreso comun
```

Inventario de endpoints publicados (`GET /swagger/v1/swagger.json`):

| Ruta | Devuelve | ¿Resumen? |
|---|---|---|
| `/api/Movimientos` | lista cruda, con filtros opcionales | No |
| `/api/Presupuestos` | lista cruda, filtro por período | No |
| `/api/Categorias` | lista cruda | No |
| `/api/MetasAhorro` | lista con `montoObjetivo`/`montoActual` | No |
| `/api/Hogares` · `/api/Usuarios` · `/api/Aportes` · `/api/TipsFinancieros` | datos maestros | No |

**No existe ningún endpoint de resumen.**

## Pasos para reproducir

1. Crear una familia y registrar movimientos.
2. `GET /swagger/v1/swagger.json` y revisar la lista de rutas: no hay nada de resumen/tablero/dashboard.
3. Para obtener el total de ingresos del mes hay que descargar la lista completa y filtrar por `tipo`, que
   además es texto libre y sensible a mayúsculas (ver `DEMO-05`).

## Comportamiento esperado

Un endpoint de resumen para el período pedido, para que el dashboard sea una sola llamada y no un volcado de
datos:

```
GET /api/Tablero?anio=2026&mes=9
{
  "totalIngresos": 400.00,
  "totalGastos": 320.00,
  "balance": 80.00,
  "totalRemesas": 400.00,              // ver DEMO-08
  "ultimosMovimientos": [ ... ],       // los 5 de la tabla
  "ingresosPorMes": [ { "mes": "2026-04", "monto": 0.00 }, ... ],
  "gastosPorCategoria": [ { "categoria": "Alimentación", "monto": 320.00 } ]
}
```

Aporte doble: el cálculo con `decimal` se hace en el servidor, que es donde hay pruebas, y la respuesta es
reducida (12 filas) en vez de los 1.000+ movimientos que la batería de `[PERF]` dejó en la base.

## Causa

El módulo de tablero nunca se implementó en el backend. Es coherente con que el guion describa el backend como
"monolito modular" con los módulos `Identidad, Movimientos, Presupuestos, Metas y Educación Financiera`: el
tablero no está en esa lista, porque la `DEMO_GUIDE` lo trata como una vista de cliente.

## Impacto

- La promesa del proyecto ("de sentir a saber el número") depende de cálculos en el cliente, sin pruebas.
- Rendimiento: el dashboard trae el histórico completo en un teléfono de gama media con datos limitados
  (justificativa de producto del propio proyecto).
- La historia de "las 4 tarjetas resumen" de la `DEMO_GUIDE` depende de filtrar por `tipo` en cliente, que es
  precisamente el campo sin validar de `DEMO-05`.

## Nota

Este hallazgo **no es necesariamente un defecto**: puede ser una decisión de diseño deliberada y aceptable (el
MVP 1 con pocos movimientos por hogar funciona igual con el cliente). Lo que sí es un riesgo es que **el
material de presentación lo describe como una capacidad del sistema sin decir que el cálculo es del cliente**.
Si se decide mantenerlo así, conviene decirlo en el guion.

## Entorno verificado
Docker Compose v2 · PostgreSQL 16 · 2026-09-27
Caso de prueba asociado: **CP-D20**, **CP-D21**, **CP-D22** (de `Ejecutar_Demo_E2E.ps1`)
