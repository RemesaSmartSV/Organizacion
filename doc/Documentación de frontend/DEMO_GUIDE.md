# Guion de Demo - RemesaSmartSV Frontend

Guion paso a paso para presentar la aplicación completa.

---

## Preparación previa

### Requisitos

- Backend ejecutándose en `localhost:5203`
- Frontend: `npm run dev` en `localhost:5173`
- Navegador Chrome o Edge actualizado
- Datos de prueba: crear al menos 2 categorías (1 Ingreso, 1 Gasto), 3-4 movimientos y 1 presupuesto

### Datos de ejemplo para la demo

**Categorías:**
- Nombre: "Salario", Tipo: Ingreso
- Nombre: "Alimentación", Tipo: Gasto
- Nombre: "Remesa familiar", Tipo: Ingreso

**Usuario de prueba:**
- Nombre: María López
- Correo: maria@demo.com
- Contraseña: 123456
- Familia: López Hernández

---

## Flujo de la Demo

### 1. Registro de usuario (2 min)

**Qué mostrar:** Primera impresión, onboarding

1. Abrir `http://localhost:5173`
2. Se muestra la pantalla de Login
3. Hacer clic en **"Crear cuenta"**
4. Completar el formulario:
   - Nombre: María López
   - Correo: maria@demo.com
   - Contraseña: 123456
   - Nombre del hogar: López Hernández
5. Hacer clic en **"Registrarse"**
6. Aparece notificación de éxito
7. Hacer clic en **"Iniciar sesión"** para volver al login

**Punto clave:** "La app crea automáticamente el hogar familiar junto con la cuenta."

---

### 2. Inicio de sesión (1 min)

**Qué mostrar:** Autenticación JWT

1. Ingresar correo: maria@demo.com
2. Ingresar contraseña: 123456
3. Hacer clic en **"Iniciar sesión"**
4. Se redirige al Dashboard
5. En el Sidebar se muestra el nombre "María" y el hogar "López Hernández"

**Punto clave:** "La sesión se mantiene al recargar la página gracias a JWT en localStorage."

---

### 3. Dashboard - Resumen financiero (3 min)

**Qué mostrar:** Vista general, gráficas, KPIs

1. Mostrar las **4 tarjetas resumen**:
   - Ingresos totales (verde)
   - Remesas recibidas (violeta)
   - Gastos totales (rojo)
   - Balance (azul)
2. Señalar la **gráfica de barras**: "Ingresos vs Gastos por mes" (últimos 6 meses)
3. Señalar la **gráfica circular**: "Distribución de Gastos por categoría"
4. Mostrar la **tabla de últimos 5 movimientos** con fecha, tipo, categoría, monto y descripción
5. Hacer clic en **"Actualizar"** para recargar datos

**Punto clave:** "El dashboard se actualiza en tiempo real con cada transacción que registres."

---

### 4. Categorías - Organizar finanzas (2 min)

**Qué mostrar:** CRUD de categorías

1. Navegar a **Categorías** desde el Sidebar
2. **Crear categoría de Ingreso:**
   - Nombre: "Salario"
   - Tipo: Ingreso
   - Guardar
3. **Crear categoría de Gasto:**
   - Nombre: "Alimentación"
   - Tipo: Gasto
   - Guardar
4. Mostrar la tabla con las categorías creadas
5. **Editar** una categoría: cambiar el nombre
6. **Eliminar** una categoría (confirmar con el modal)

**Punto clave:** "Las categorías te permiten clasificar y analizar tus finanzas por tipo."

---

### 5. Registrar movimientos (3 min)

**Qué mostrar:** Flujo completo de transacciones

1. Navegar a **Movimientos** desde el Sidebar
2. **Crear un Ingreso (Salario):**
   - Tipo: Ingreso
   - Categoría: Salario
   - Monto: $1,200.00
   - Fecha: fecha de hoy
   - Descripción: "Pago quincenal"
   - Guardar
3. **Crear un Gasto:**
   - Tipo: Gasto
   - Categoría: Alimentación
   - Monto: $85.50
   - Fecha: fecha de hoy
   - Descripción: "Compra supermercado"
   - Guardar
4. Mostrar la **tabla paginada** con los movimientos
5. **Filtrar** por tipo "Ingreso" → mostrar solo ingresos
6. **Buscar** por texto "supermercado"
7. **Exportar a CSV** → descargar archivo

**Punto clave:** "Cada movimiento se registra con categoría, fecha y descripción para un análisis completo."

---

### 6. Remesas (3 min)

**Qué mostrar:** Gestión de remesas recibidas del exterior

1. Navegar a **Remesas** desde el Sidebar
2. **Crear una Remesa:**
   - Categoría: "Remesa familiar" (tipo Ingreso)
   - Monto: $350.00
   - Fecha: fecha de hoy
   - Origen/Emisor: "Tío Carlos - Los Ángeles"
   - Descripción: "Remesa mensual"
   - Guardar
3. Mostrar la tabla de remesas con acento violeta
4. **Filtrar** por fecha desde/hasta
5. **Exportar a CSV**

**Punto clave:** "Las remesas se separan de otros ingresos para un seguimiento específico del dinero que llega del exterior."

---

### 7. Presupuestos - Control de gastos (3 min)

**Qué mostrar:** Límites y barras de progreso

1. Navegar a **Presupuestos** desde el Sidebar
2. **Crear un presupuesto:**
   - Categoría: Alimentación
   - Monto límite: $500.00
   - Mes: mes actual
   - Guardar
3. Mostrar la **barra de progreso**:
   - Si los gastos son <$350 (70%): barra verde
   - Si están entre $350-$445 (70-89%): barra amarilla
   - Si superan $445 (90%+): barra roja
4. **Crear otro presupuesto** para comparar
5. **Filtrar** por categoría o mes
6. **Exportar a CSV**

**Punto clave:** "Las barras de progreso te muestran visualmente cuánto te falta del presupuesto asignado."

---

### 8. Educación Financiera (1 min)

**Qué mostrar:** Contenido informativo

1. Navegar a **Educación Financiera** desde el Sidebar
2. Mostrar el **hero banner** con gradiente azul-cyan
3. Mostrar las **tarjetas de tips** en grid responsive
4. Cada tarjeta tiene: título, contenido y categoría
5. Explicar que esta sección es de solo lectura

**Punto clave:** "Educación financiera integrada para ayudar a las familias a tomar mejores decisiones."

---

### 9. Responsive / Móvil (1 min)

**Qué mostrar:** Adaptabilidad móvil

1. Redimensionar la ventana del navegador a tamaño móvil (< 768px)
2. El **Sidebar se oculta** automáticamente
3. Aparece el **botón hamburguesa** en el Navbar
4. Hacer clic en el hamburguesa → el Sidebar se desliza desde la izquierda
5. Hacer clic fuera del Sidebar → se cierra con overlay oscuro
6. Navegar por diferentes páginas en modo móvil

**Punto clave:** "La app se adapta a cualquier tamaño de pantalla para usarla desde el celular."

---

### 10. Cierre de sesión (30 seg)

**Qué mostrar:** Seguridad de sesión

1. Hacer clic en **"Cerrar sesión"** en el Sidebar
2. Se limpia todo el estado y se redirige al Login
3. Intentar navegar directamente a `/dashboard` → redirige al Login
4. Recargar la página → permanece en Login (sesión limpiada)

**Punto clave:** "La sesión se cierra de forma segura y el token se invalida."

---

## Resumen de features a mencionar

| Feature | Dónde se ve |
|---|---|
| JWT Authentication | Login/Register |
| Dashboard con gráficas | Página principal |
| CRUD completo | Movimientos, Categorías, Remesas, Ingresos, Gastos, Presupuestos |
| Filtros avanzados | Todas las páginas con tabla |
| Exportar CSV | Todas las páginas con tabla |
| Barras de progreso | Presupuestos |
| Gráficas interactivas | Dashboard |
| Diseño responsive | Toda la app |
| Lazy loading | Todas las páginas |
| Notificaciones toast | CRUD operations |
| Modal de confirmación | Eliminar registros |

---

## Tiempo estimado total

| Sección | Tiempo |
|---|---|
| Registro + Login | 3 min |
| Dashboard | 3 min |
| Categorías | 2 min |
| Movimientos | 3 min |
| Remesas | 3 min |
| Presupuestos | 3 min |
| Educación Financiera | 1 min |
| Responsive | 1 min |
| Cierre | 0.5 min |
| **Total** | **~19-20 min** |

---

## Tips para la presentación

1. **Tener datos precargados** — No perder tiempo creando todo en vivo. Crear 4-5 movimientos antes de la demo.
2. **Navegar con el mouse** — Señalar cada sección del Sidebar al ir navigando.
3. **Mostrar notificaciones** — Cuando se crea o elimina algo, pausar para que se vea el toast.
4. **Redimensionar el navegador** — Al menos una vez para mostrar responsive.
5. **Hablar del contexto** — "Esto está diseñado para familias salvadoreñas que reciben remesas y necesitan organizar sus finanzas."
6. **Mencionar el stack** — React + Tailwind + Vite + .NET backend + Docker.
