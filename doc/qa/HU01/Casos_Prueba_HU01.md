# Casos de Prueba — HU-01 (Gestión de Hogares, Miembros, Roles y Autenticación JWT)
**Proyecto:** RemesaSmart SV — CasaTIC
**Responsable:** Emelie
**Fecha:** Sábado 22 (actualizado Domingo 23 con endpoints reales del repo `backend`)

> Endpoints confirmados directamente del código en `RemesaSmartSV/backend` (rama `develop`, la de integración). Base URL con Docker Compose: `http://localhost:8080` (Swagger en `/swagger`). Frontend: `http://localhost:5173`.

## 0. Notas del modelo real
- El **registro crea el hogar y el usuario administrador en la misma llamada** (`POST /api/Auth/register`). No existe un endpoint separado para "crear hogar".
- Roles válidos: `"Admin"` y `"Miembro"` (con mayúscula inicial).
- El JWT expira en **8 horas** y contiene los claims `idUsuario`, `idHogar`, `role`, `email`.
- ⚠️ `PUT /api/Hogares/{id}` no exige rol Admin — cualquier usuario autenticado del hogar puede renombrarlo. Confirmar con el equipo si es intencional (ver CP-16).

## 1. Registro y Autenticación (`/api/Auth`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-01 | Registro exitoso (crea hogar + admin) | POST /api/Auth/register `{Nombre, Correo, Contrasena, NombreFamiliar}` | 200 con `LoginResponse` (Token, IdUsuario, Nombre, Correo, Rol="Admin", IdHogar nuevo) | Alta |
| CP-02 | Registro con correo duplicado | POST /api/Auth/register con correo existente | 409 Conflict, mensaje "El correo ya está registrado." | Alta |
| CP-03 | Registro con campos faltantes | POST /api/Auth/register sin Correo o Contrasena | 400 (falla de validación `[Required]`) | Media |
| CP-04 | Registro con contraseña corta | POST con Contrasena de menos de 6 caracteres | 400 (`MinLength(6)`) | Media |
| CP-05 | Login exitoso | POST /api/Auth/login `{Correo, Contrasena}` correctos | 200 con Token y datos del usuario | Alta |
| CP-06 | Login con password incorrecto | POST /api/Auth/login con Contrasena errónea | 401 Unauthorized, mensaje "Credenciales incorrectas." | Alta |
| CP-07 | Login con correo inexistente | POST /api/Auth/login con correo no registrado | 401 Unauthorized | Alta |
| CP-08 | Estructura del JWT | Decodificar el Token recibido en login | Contiene claims idUsuario, idHogar, role, email; expira en 8h | Alta |
| CP-09 | Expiración del JWT | Usar un token vencido en un endpoint protegido | 401 | Media |
| CP-10 | Acceso sin token | GET /api/Hogares sin header Authorization | 401 | Alta |
| CP-11 | Acceso con token alterado | Modificar manualmente el Token y llamarlo | 401 (firma inválida) | Alta |

## 2. Hogares (`/api/Hogares`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-12 | Consultar mi hogar | GET /api/Hogares (autenticado) | 200 con el hogar cuyo IdHogar coincide con el claim del token | Alta |
| CP-13 | Consultar hogar sin token | GET /api/Hogares sin Authorization | 401 | Alta |
| CP-14 | Editar nombre del hogar (rol Admin) | PUT /api/Hogares/{miIdHogar} `{NombreFamiliar}` | 204 No Content, nombre actualizado | Alta |
| CP-15 | Editar nombre del hogar (rol Miembro) | PUT /api/Hogares/{miIdHogar} autenticado como Miembro | Según código actual: 204 (sin restricción de rol) — **confirmar con el equipo si debería ser 403** | Alta ⚠️ |
| CP-16 | Editar hogar ajeno (id de otro hogar) | PUT /api/Hogares/{idDeOtroHogar} | 404 NotFound (el controlador compara `hogar.IdHogar != User.GetIdHogar()`) | Alta |
| CP-17 | Eliminar hogar sin ser Admin | DELETE /api/Hogares/{miIdHogar} como Miembro | 403 Forbidden (`[Authorize(Roles="Admin")]`) | Alta |
| CP-18 | Eliminar hogar siendo Admin | DELETE /api/Hogares/{miIdHogar} como Admin | 204 No Content | Media |

## 3. Miembros del Hogar (`/api/Usuarios`)

| ID | Descripción | Endpoint | Resultado esperado | Prioridad |
|----|-------------|----------|---------------------|-----------|
| CP-19 | Listar miembros de mi hogar | GET /api/Usuarios (autenticado) | 200 con todos los usuarios de mi IdHogar, ordenados por nombre | Alta |
| CP-20 | Agregar miembro (rol Admin) | POST /api/Usuarios `{Nombre, Correo, Contrasena, Rol?}` como Admin | 201 Created, usuario creado con Rol="Miembro" si no se especifica | Alta |
| CP-21 | Agregar miembro con correo duplicado | POST /api/Usuarios con correo ya existente | 409 Conflict | Media |
| CP-22 | Agregar miembro sin ser Admin | POST /api/Usuarios como Miembro | 403 Forbidden | Alta |
| CP-23 | Editar rol de un miembro (Admin) | PUT /api/Usuarios/{id} `{Rol: "Admin"}` | 204, rol actualizado | Alta |
| CP-24 | Editar rol sin ser Admin | PUT /api/Usuarios/{id} como Miembro | 403 Forbidden | Alta |
| CP-25 | Eliminar miembro (Admin) | DELETE /api/Usuarios/{idOtroUsuario} como Admin | 204 No Content | Media |
| CP-26 | Intentar eliminarse a sí mismo | DELETE /api/Usuarios/{miPropioId} como Admin | 400 BadRequest "No puedes eliminar tu propio usuario." | Media |
| CP-27 | Eliminar miembro sin ser Admin | DELETE /api/Usuarios/{id} como Miembro | 403 Forbidden | Alta |

## Resumen
- Total de casos: 27
- Cobertura: registro (crea hogar+admin), login, JWT (claims/expiración/validación), hogar (consulta/edición/eliminación), miembros (listar/agregar/editar/eliminar), control de acceso por rol.
- **Hallazgo a validar con el equipo:** CP-15 — cualquier miembro autenticado puede renombrar el hogar; no hay restricción de rol en `PUT /api/Hogares/{id}`. Si no es intencional, es un bug a reportar hoy.
