# RemesaSmartSV - Frontend

Aplicación web de gestión financiera familiar diseñada para la comunidad salvadoreña. Permite administrar remesas, ingresos, gastos, presupuestos y ofrece educación financiera.

---

## Tabla de contenidos

- [Características](#características)
- [Tecnologías](#tecnologías)
- [Requisitos previos](#requisitos-previos)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Docker](#docker)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Rutas disponibles](#rutas-disponibles)
- [Configuración](#configuración)
- [API Endpoints](#api-endpoints)

---

## Características

- **Dashboard financiero** — Resumen con tarjetas de Ingresos, Remesas, Gastos y Balance. Gráficas de barras (ingresos vs gastos) y circular (gastos por categoría) con Recharts.
- **Movimientos** — CRUD completo de transacciones con filtros por texto, fechas, categoría y monto. Exportar a CSV.
- **Remesas** — Gestión de remesas recibidas con origen/emisor. Filtrado y exportación CSV.
- **Ingresos** — Ingresos sin origen específico. CRUD con filtros y exportación.
- **Gastos** — Seguimiento de gastos del hogar. CRUD con filtros y exportación.
- **Categorías** — Crear y administrar categorías de tipo Ingreso o Gasto con iconos personalizados.
- **Presupuestos** — Definir límites por categoría y mes. Barras de progreso con semáforo visual (verde/amarillo/rojo).
- **Educación Financiera** — Tips financieros informativos en tarjetas visuales.
- **Autenticación JWT** — Login/registro con token JWT, persistencia de sesión y expiración automática.
- **Diseño responsive** — Sidebar colapsable en móvil, layout adaptable con Tailwind CSS.

---

## Tecnologías

| Tecnología | Versión | Uso |
|---|---|---|
| React | ^18.3.1 | UI library |
| React Router DOM | ^7.18.3 | Enrutamiento SPA |
| Vite | ^6.0.0 | Bundler y dev server |
| Tailwind CSS | ^4.3.3 | Framework de estilos |
| Recharts | ^3.10.1 | Gráficas (barras, circular) |
| Lucide React | ^1.43.0 | Iconos SVG |
| Nginx | latest | Servidor estático en producción |
| Node.js | 20 | Build time |

---

## Requisitos previos

- [Node.js](https://nodejs.org/) 20 o superior
- npm
- Backend ejecutándose en `localhost:5203` (para desarrollo)
- Docker y Docker Compose (opcional, para despliegue)

---

## Instalación y ejecución

### 1. Instalar dependencias

```bash
cd frontend
npm install
```

### 2. Ejecutar en modo desarrollo

```bash
npm run dev
```

La app está disponible en **http://localhost:5173**

En desarrollo, todas las peticiones a `/api` se redirigen automáticamente al backend en `http://localhost:5203` (configurado en `vite.config.js`).

### 3. Build de producción

```bash
npm run build
```

Genera la carpeta `dist/` optimizada para producción.

### 4. Preview del build

```bash
npm run preview
```

Vista previa del build de producción localmente.

---

## Docker

### Construir y ejecutar con Docker

```bash
cd frontend
docker build -t remesasmart-frontend .
docker run -p 80:80 remesasmart-frontend
```

### Usar Docker Compose (recomendado)

Si el proyecto raíz tiene un `docker-compose.yml`:

```bash
docker-compose up --build
```

El frontend se servirá en el puerto 80 y proxea las llamadas `/api` al backend en `backend_api:8080`.

### Arquitectura Docker (multi-etapa)

1. **Build** — Node 20 Alpine: instala dependencias y ejecuta `npm run build`
2. **Producción** — Nginx Alpine: sirve archivos estáticos + proxy reverso al backend

---

## Estructura del proyecto

```
frontend/
├── public/
├── src/
│   ├── assets/                    # Imágenes (logo, hero, etc.)
│   ├── components/                # Componentes reutilizables
│   │   ├── Layout.jsx             # Shell: Navbar + Sidebar + Outlet
│   │   ├── Navbar.jsx             # Header superior sticky
│   │   ├── Sidebar.jsx            # Navegación lateral
│   │   ├── Loading.jsx            # Spinner animado
│   │   ├── Notification.jsx       # Toast notifications
│   │   ├── Pagination.jsx         # Paginador numérico
│   │   └── ConfirmModal.jsx       # Modal de confirmación
│   ├── pages/                     # Páginas/rutas
│   │   ├── Login.jsx              # Inicio de sesión
│   │   ├── Register.jsx           # Registro de usuario
│   │   ├── Dashboard.jsx          # Resumen financiero + gráficas
│   │   ├── Movimientos.jsx        # CRUD movimientos
│   │   ├── Categorias.jsx         # CRUD categorías
│   │   ├── Remesas.jsx            # CRUD remesas
│   │   ├── Ingresos.jsx           # CRUD ingresos
│   │   ├── Gastos.jsx             # CRUD gastos
│   │   ├── Presupuestos.jsx       # CRUD presupuestos + barras
│   │   └── EducacionFinanciera.jsx # Tips financieros
│   ├── services/
│   │   └── api.js                 # Capa HTTP (fetch + JWT)
│   ├── utils/
│   │   └── formato.js             # formatearMoneda(), obtenerFechaHoy()
│   ├── App.jsx                    # Rutas + auth + layout principal
│   ├── main.jsx                   # Entry point React
│   └── Index.css                  # Tailwind import
├── Dockerfile                     # Build multi-etapa
├── nginx.conf                     # Proxy /api en producción
├── package.json
├── vite.config.js
└── index.html
```

---

## Rutas disponibles

| Ruta | Página | Descripción |
|---|---|---|
| `/` | Dashboard | Resumen financiero con gráficas |
| `/movimientos` | Movimientos | CRUD de transacciones con filtros |
| `/categorias` | Categorías | Administrar categorías |
| `/remesas` | Remesas | Gestionar remesas recibidas |
| `/ingresos` | Ingresos | Gestionar ingresos |
| `/gastos` | Gastos | Gestionar gastos |
| `/presupuestos` | Presupuestos | Definir límites por categoría |
| `/educacion-financiera` | Educación Financiera | Tips financieros |

Las rutas `/login` y `/register` están fuera del router autenticado.

---

## Configuración

### Variables de entorno

No se requieren archivos `.env` para desarrollo. La URL base de la API está configurada en:

- **Desarrollo:** `vite.config.js` → proxy de `/api` a `http://localhost:5203`
- **Producción:** `nginx.conf` → proxy de `/api` a `http://backend_api:8080/api/`

### Autenticación

- JWT almacenado en `localStorage`
- El token se valida automáticamente al recargar la página
- Sesión expirada redirige al login con mensaje informativo
- Logout limpio de `localStorage`

---

## API Endpoints

El frontend consume los siguientes endpoints del backend:

| Método | Endpoint | Descripción |
|---|---|---|
| POST | `/api/Auth/login` | Inicio de sesión |
| POST | `/api/Auth/register` | Registro de usuario |
| GET | `/api/Movimientos` | Listar movimientos |
| POST | `/api/Movimientos` | Crear movimiento |
| PUT | `/api/Movimientos/{id}` | Actualizar movimiento |
| DELETE | `/api/Movimientos/{id}` | Eliminar movimiento |
| GET | `/api/Categorias` | Listar categorías |
| POST | `/api/Categorias` | Crear categoría |
| PUT | `/api/Categorias/{id}` | Actualizar categoría |
| DELETE | `/api/Categorias/{id}` | Eliminar categoría |
| GET | `/api/Presupuestos` | Listar presupuestos |
| POST | `/api/Presupuestos` | Crear presupuesto |
| PUT | `/api/Presupuestos/{id}` | Actualizar presupuesto |
| DELETE | `/api/Presupuestos/{id}` | Eliminar presupuesto |
| GET | `/api/TipsFinancieros` | Listar tips financieros |
