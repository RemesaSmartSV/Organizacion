# Entrega — Pruebas funcionales HU-01 · RemesaSmart SV

**Responsable:** Emelie · **Rol:** QA / Testing funcional y de permisos
**Alcance:** HU-01 — Gestión de Hogares, Miembros, Roles y Autenticación JWT
**Fecha de ejecución:** Domingo 23 (entorno integrado con código real de la rama `develop`)

---

## Resultado en una línea

> **27 casos ejecutados · 25 pasaron ✅ · 2 fallaron ❌ (2 bugs reportados) · 0 bloqueados ⏸️**

| Bug | Caso | Resumen | Severidad |
|-----|------|---------|-----------|
| [BUG-01](issues/BUG-01-jwt-sin-claim-role-corto.md) | CP-08 | El JWT no trae el claim corto `role` (usa el URI largo de Microsoft) ni `iat`; rompería la lógica de rol en frontend. Vigencia 8 h sí correcta. | Media |
| [BUG-02](issues/BUG-02-put-hogares-sin-restriccion-rol.md) | CP-15 | `PUT /api/Hogares/{id}` permite renombrar el hogar a cualquier Miembro (falta `[Authorize(Roles="Admin")]`). Confirmado: 204 en vez de 403. | Media-Alta |

## Qué se hizo

1. **Verificación de contrato:** los 27 casos se contrastaron contra el código real (`AuthController`, `HogaresController`, `UsuariosController`, `AuthService`) antes de ejecutar.
2. **Ambiente integrado:** `docker compose up` con PostgreSQL 16 + API .NET 8 en `http://localhost:8080`.
3. **Ejecución automatizada** de los 27 casos vía script PowerShell (HTTP real, sin Postman manual), incluyendo:
   - Fabricación de un **JWT vencido firmado** para probar expiración sin esperar 8 h (CP-09).
   - Verificaciones post-condición en BD (p. ej., tras editar nombre/rol se reconsultó la API para confirmar el cambio).
4. **Documentación de bugs** listos para crear como issues en GitHub.

## Contenido de esta carpeta

| Archivo | Descripción |
|---------|-------------|
| `./Casos_Prueba_HU01.md` | Diseño de los 27 casos (entrada del proceso) |
| `Ejecucion_Pruebas_HU01_resultados.md` | **Hoja oficial de ejecución llena** (entregable principal) |
| `issues/BUG-01-jwt-sin-claim-role-corto.md` | Issue listo para pegar en GitHub |
| `issues/BUG-02-put-hogares-sin-restriccion-rol.md` | Issue listo para pegar en GitHub |
| `resultados_HU01.csv` / `.json` | Resultados maquinables (25 PASS, 2 FAIL) |
| `evidencia_raw.log` | Request/response cruda de cada caso |
| `Ejecutar_Pruebas_HU01.ps1` | Script re-ejecutable de toda la batería |

## Cómo reproducir la ejecución

```powershell
# 1. Levantar entorno (requiere Docker Desktop)
cd backend
docker compose up -d --build postgres_db backend_api

# 2. Esperar ~30 s y ejecutar la batería completa
cd ..
powershell -ExecutionPolicy Bypass -File pruebas-hu01\Ejecutar_Pruebas_HU01.ps1
```

El script es idempotente solo contra una base limpia; si se re-ejecuta, limpiar primero con `docker compose down -v`.

## Notas para el equipo

- **Decisión pendiente (BUG-02):** confirmar si la especificación exige que solo Admin renombre el hogar. Si es intencional permitirlo a Miembros, cerrar el issue como *works as designed* y actualizar CP-15.
- **Coordinación BUG-01:** al corregir el claim `role`, avisar al equipo de frontend (quienes consumen el payload decodificado) y validar usuarios ya registrados.
- Datos semilla creados durante las pruebas: hogar *"Familia Gonzalez HU01"* (Carlos Admin · Ana, Luis Miembros), útil para pruebas manuales rápidas.
