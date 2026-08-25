# Ejecución de Casos de Prueba — HU-01 (sobre entorno integrado)
**Fecha de ejecución:** Domingo 23
**Ejecutado por:** Emelie (ejecución automatizada asistida)
**Base:** endpoints reales verificados en `RemesaSmartSV/backend` (rama `develop`)
**Entorno:** Docker Compose local — API `http://localhost:8080` (contenedor `remesasmart_backend`) + PostgreSQL 16 (`remesasmart_postgres`)

> Instrucciones: marca cada caso como ✅ Pasó, ❌ Falló o ⏸️ Bloqueado. Si falla, anota el ID del bug (usa `Reporte_Bugs_HU01.md`).

## 1. Registro y Autenticación

| ID | Descripción | Resultado | Bug asociado | Observaciones |
|----|-------------|-----------|---------------|----------------|
| CP-01 | Registro exitoso (crea hogar + admin) | ✅ Pasó | — | 200 con LoginResponse; Rol="Admin", IdHogar=1 creado en la misma llamada |
| CP-02 | Registro con correo duplicado | ✅ Pasó | — | 409 Conflict, mensaje "El correo ya está registrado." |
| CP-03 | Registro con campos faltantes | ✅ Pasó | — | 400 con ValidationProblemDetails (fallo `[Required]`) |
| CP-04 | Registro con contraseña corta | ✅ Pasó | — | 400 por `MinLength(6)` |
| CP-05 | Login exitoso | ✅ Pasó | — | 200 con Token y datos del usuario |
| CP-06 | Login con password incorrecto | ✅ Pasó | — | 401, mensaje "Credenciales incorrectas." |
| CP-07 | Login con correo inexistente | ✅ Pasó | — | 401 Unauthorized |
| CP-08 | Estructura del JWT | ❌ Falló | BUG-01 | Ver detalle abajo. Vigencia correcta (exp = emisión + 28800 s ≈ 8 h) y claims `idUsuario`, `idHogar`, `email` presentes. **Pero el claim de rol NO viene como `role`**, sino como URI largo `"http://schemas.microsoft.com/ws/2008/06/identity/claims/role":"Admin"`. Además el token no incluye `iat`. Impacto frontend: al decodificar con jwt-decode, `payload.role` es `undefined`. Server-side sí funciona (`User.IsInRole`). |
| CP-09 | Expiración del JWT | ✅ Pasó | — | Token fabricado vencido (misma clave dev de appsettings, exp −2 h) → 401. Nota técnica: no se esperaron 8 h reales; se validó la firma del token expirado. |
| CP-10 | Acceso sin token | ✅ Pasó | — | GET /api/Hogares sin header → 401 |
| CP-11 | Acceso con token alterado | ✅ Pasó | — | Último carácter de la firma modificado → 401 |

## 2. Hogares

| ID | Descripción | Resultado | Bug asociado | Observaciones |
|----|-------------|-----------|---------------|----------------|
| CP-12 | Consultar mi hogar | ✅ Pasó | — | 200; `idHogar` del body coincide con el claim del token |
| CP-13 | Consultar hogar sin token | ✅ Pasó | — | 401 |
| CP-14 | Editar nombre del hogar (Admin) | ✅ Pasó | — | 204; verificado en BD: nombre actualizado a "Familia Gonzalez Perez" |
| CP-15 | Editar nombre del hogar (Miembro) ⚠️ | ❌ Falló (confirma hallazgo) | BUG-02 | **CONFIRMADO**: un usuario con rol "Miembro" obtuvo **204** al renombrar el hogar (PUT /api/Hogares/{id} sin restricción de rol). Si la especificación exige solo Admin, es bug de seguridad/permisos (media-alta). El endpoint devuelve 404 para hogares ajenos, pero 204 para el propio aunque el rol sea Miembro. |
| CP-16 | Editar hogar ajeno (id de otro hogar) | ✅ Pasó | — | PUT con idHogar=2 (hogar de Marta) usando token de Carlos → 404 NotFound (comparación `hogar.IdHogar != User.GetIdHogar()`) |
| CP-17 | Eliminar hogar sin ser Admin | ✅ Pasó | — | DELETE como Miembro → 403 Forbidden (`[Authorize(Roles="Admin")]`) |
| CP-18 | Eliminar hogar siendo Admin | ✅ Pasó | — | 204 No Content (se eliminó el hogar de prueba "Familia Martinez HU01" para preservar los datos principales) |

## 3. Miembros del Hogar

| ID | Descripción | Resultado | Bug asociado | Observaciones |
|----|-------------|-----------|---------------|----------------|
| CP-19 | Listar miembros de mi hogar | ✅ Pasó | — | 200; [Ana Gonzalez, Carlos Gonzalez] ordenado por nombre; solo usuarios del propio hogar |
| CP-20 | Agregar miembro (Admin) | ✅ Pasó | — | 201 Created; Rol="Miembro" por defecto. *Ejecutado antes de CP-12 por dependencia (se necesitaba un Miembro para CP-15/CP-17).* |
| CP-21 | Agregar miembro con correo duplicado | ✅ Pasó | — | 409 Conflict, mensaje claro |
| CP-22 | Agregar miembro sin ser Admin | ✅ Pasó | — | POST como Miembro → 403 Forbidden |
| CP-23 | Editar rol de un miembro (Admin) | ✅ Pasó | — | PUT {rol:"Admin"} sobre id=4 → 204; verificado en lista: rol quedó "Admin". Se restauró a "Miembro" después. |
| CP-24 | Editar rol sin ser Admin | ✅ Pasó | — | PUT como Miembro → 403 Forbidden |
| CP-25 | Eliminar miembro (Admin) | ✅ Pasó | — | 204 No Content (usuario temporal creado para la prueba) |
| CP-26 | Intentar eliminarse a sí mismo | ✅ Pasó | — | 400 BadRequest, mensaje "No puedes eliminar tu propio usuario." |
| CP-27 | Eliminar miembro sin ser Admin | ✅ Pasó | — | DELETE como Miembro → 403 Forbidden |

## Resumen de ejecución
- Total de casos: 27
- ✅ Pasaron: **25**
- ❌ Fallaron: **2** (CP-08 y CP-15)
- ⏸️ Bloqueados: **0**

### Bugs / hallazgos reportados
| ID | Caso | Severidad sugerida | Descripción |
|----|------|--------------------|-------------|
| BUG-01 | CP-08 | Media | El JWT serializa el rol con el nombre largo `"http://schemas.microsoft.com/ws/2008/06/identity/claims/role"` en lugar de `"role"`, y omite `iat`. El contrato documentado (claims `role`) no se cumple; rompería la lógica de UI basada en `payload.role`. Causa probable: `JwtSecurityTokenHandler` + `ClaimTypes.Role` sin `DefaultOutboundClaimTypeMap` limpio o uso de `JwtRegisteredClaimNames` explícito en `AuthService.GenerateToken`. |
| BUG-02 | CP-15 | Media-Alta | `PUT /api/Hogares/{id}` permite que cualquier usuario autenticado del hogar (rol "Miembro") renombre el hogar; falta `[Authorize(Roles="Admin")]` o verificación manual de rol en `HogaresController.Update`. Confirmado empíricamente: Miembro recibió 204. |

### Notas de ejecución
- Orden alterado puntual por dependencias: CP-20 se ejecutó antes de CP-12 (hizo falta un usuario Miembro para CP-15 y CP-17). El resto siguió el orden numérico.
- Evidencia cruda completa (request/response de cada caso) en `evidencia_raw.log`; resumen maquina en `resultados_HU01.csv`.
- Datos creados durante la prueba: hogar "Familia Gonzalez HU01" (Carlos Admin, Ana y Luis Miembros) queda persistido como semilla de datos.
