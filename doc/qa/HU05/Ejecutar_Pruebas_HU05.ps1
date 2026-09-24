# ============================================================
# Ejecucion de Casos de Prueba HU-05 - Presupuestos - RemesaSmart SV
# Jueves 27 - contra entorno integrado Docker (localhost:8080)
# NOTA: casos con esperado "comportamiento real" (CP-06, 10-13, 16-17, 24)
# dependen de los criterios de aceptacion de HU-05; revisar OBS en el diseno.
# ============================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$base = 'http://localhost:8080'
$logFile = Join-Path $PSScriptRoot 'evidencia_raw.log'

$client = [System.Net.Http.HttpClient]::new()
$client.BaseAddress = [Uri]'http://localhost:8080/'
$client.Timeout = [TimeSpan]::FromSeconds(30)
"=== Ejecucion HU-05 $(Get-Date -Format s) ===" | Set-Content $logFile

$results = New-Object System.Collections.Generic.List[object]

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body, [string]$Token)
    $msg = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $Path)
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 8 -Compress
        $msg.Content = [System.Net.Http.StringContent]::new($json, [Text.Encoding]::UTF8, 'application/json')
    }
    if ($Token) { $msg.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token) }
    $resp = $client.SendAsync($msg).GetAwaiter().GetResult()
    $respBody = ''
    if ($resp.Content) { $respBody = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult() }
    ("{0} {1} -> {2}" -f $Method, $Path, [int]$resp.StatusCode) | Add-Content $logFile
    if ($Token) { "Auth: Bearer $($Token.Substring(0, [Math]::Min(30, $Token.Length)))..." | Add-Content $logFile }
    if ($Body) { ("ReqBody: " + ($Body | ConvertTo-Json -Depth 8 -Compress)) | Add-Content $logFile }
    if ($respBody) { ("RespBody: " + $respBody.Substring(0, [Math]::Min(500, $respBody.Length))) | Add-Content $logFile }
    "" | Add-Content $logFile
    @{ Code = [int]$resp.StatusCode; Body = $respBody }
}

function Add-Resultado([string]$Id, [string]$Desc, $Esperado, $Obtenido, [bool]$Pass, [string]$Obs = '') {
    $estado = if ($Pass) { 'PASO' } else { 'FALLO' }
    $results.Add([pscustomobject]@{ ID = $Id; Descripcion = $Desc; Esperado = $Esperado; Obtenido = $Obtenido; Resultado = $estado; Observaciones = $Obs })
    $icon = if ($Pass) { '[PASS]' } else { '[FAIL]' }
    Write-Output ("{0} {1,-6} esperado={2,-22} obtenido={3,-18} {4}" -f $icon, $Id, $Esperado, $Obtenido, $Obs)
}

Write-Output '===== SETUP: hogares, miembro y categorias ====='

# --- Setup Hogar A (Carlos Admin) ---
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Carlos Hu05'; correo = 'carlos.hu05@demo-test.com'; contrasena = 'Demo1234!'; nombreFamiliar = 'Familia Demo HU05' }
if ($r.Code -ne 200) { throw "Falló el registro del Hogar A: $($r.Body)" }
$carlos = $r.Body | ConvertFrom-Json
$tokenA = $carlos.Token
$idHogarA = [int]$carlos.IdHogar
Write-Output "Hogar A listo: idHogar=$idHogarA usuario=$($carlos.Nombre)"

# --- Setup Hogar B (Marta) ---
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Marta Hu05'; correo = 'marta.hu05@demo-test.com'; contrasena = 'Demo1234!'; nombreFamiliar = 'Familia B HU05' }
if ($r.Code -ne 200) { throw "Falló el registro del Hogar B: $($r.Body)" }
$marta = $r.Body | ConvertFrom-Json
$tokenB = $marta.Token
$idHogarB = [int]$marta.IdHogar

# --- Categorias Hogar A ---
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Alimentacion'; tipo = 'Gasto'; icono = 'manzana' } $tokenA
$idCatAlim = ($r.Body | ConvertFrom-Json).idCategoria
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Salario'; tipo = 'Ingreso'; icono = 'moneda' } $tokenA
$idCatSal = ($r.Body | ConvertFrom-Json).idCategoria
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Transporte'; tipo = 'Gasto'; icono = 'bus' } $tokenA
$idCatTran = ($r.Body | ConvertFrom-Json).idCategoria
Write-Output "Categorias A: alim=$idCatAlim sal=$idCatSal tran=$idCatTran"

# --- Miembro Ana (Hogar A) ---
$r = Invoke-Api 'POST' '/api/Usuarios' @{ nombre = 'Ana Hu05'; correo = 'ana.hu05@demo-test.com'; contrasena = 'Demo1234!'; rol = 'Miembro' } $tokenA
if ($r.Code -ne 201) { throw "Falló crear a Ana: $($r.Body)" }
$r = Invoke-Api 'POST' '/api/Auth/login' @{ correo = 'ana.hu05@demo-test.com'; contrasena = 'Demo1234!' }
$tokenAna = ($r.Body | ConvertFrom-Json).Token

# --- Categoria + presupuesto Hogar B (para aislamiento) ---
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Educacion'; tipo = 'Gasto'; icono = 'libro' } $tokenB
$idCatB = ($r.Body | ConvertFrom-Json).idCategoria
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatB; montoLimite = 500.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenB
$idPresB = ($r.Body | ConvertFrom-Json).idPresupuesto
Write-Output "Hogar B listo: idHogar=$idHogarB catB=$idCatB presB=$idPresB"

# ============================================================
Write-Output ''
Write-Output '===== SECCION 1: Seguridad y aislamiento ====='

# --- CP-01: Crear presupuesto sin token ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatAlim; montoLimite = 100.00; mesAnio = '2026-09-01T00:00:00Z' } $null
Add-Resultado 'CP-01' 'Crear presupuesto sin token' '401 Unauthorized' $r.Code ($r.Code -eq 401)

# --- CP-02: Listar presupuestos sin token ---
$r = Invoke-Api 'GET' '/api/Presupuestos' $null $null
Add-Resultado 'CP-02' 'Listar presupuestos sin token' '401 Unauthorized' $r.Code ($r.Code -eq 401)

# --- CP-03: Crear con token alterado ---
$arr = $tokenA.ToCharArray(); $arr[$arr.Length - 1] = if ($arr[$arr.Length - 1] -eq 'A') { 'B' } else { 'A' }
$tokenAlterado = -join $arr
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatAlim; montoLimite = 100.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenAlterado
Add-Resultado 'CP-03' 'Crear con token alterado (firma invalida)' '401 Unauthorized' $r.Code ($r.Code -eq 401)

# --- CP-04: Consultar presupuesto de otro hogar ---
$r = Invoke-Api 'GET' "/api/Presupuestos/$idPresB" $null $tokenA
Add-Resultado 'CP-04' "Consultar presupuesto de otro hogar (id=$idPresB)" '404 NotFound' $r.Code ($r.Code -eq 404)

# --- CP-05: Inyectar idHogar ajeno en el body ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatAlim; montoLimite = 100.00; mesAnio = '2026-09-01T00:00:00Z'; idHogar = $idHogarB } $tokenA
$idPres05 = ($r.Body | ConvertFrom-Json).idPresupuesto
$hogarEnBody = ($r.Body | ConvertFrom-Json).idHogar
Add-Resultado 'CP-05' 'Inyectar idHogar ajeno en el body' "201 y idHogar=$idHogarA (del token)" $r.Code (($r.Code -eq 201) -and ($hogarEnBody -eq $idHogarA)) "idHogar response=$hogarEnBody"

# --- CP-06: Operar como rol Miembro (comportamiento real, ver OBS-05) ---
$rC = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatTran; montoLimite = 80.00; mesAnio = '2026-10-01T00:00:00Z' } $tokenAna
$idAnaPres = ($rC.Body | ConvertFrom-Json).idPresupuesto
$rE = Invoke-Api 'PUT' "/api/Presupuestos/$idAnaPres" @{ idCategoria = $idCatTran; montoLimite = 90.00; mesAnio = '2026-10-01T00:00:00Z' } $tokenAna
$rD = Invoke-Api 'DELETE' "/api/Presupuestos/$idAnaPres" $null $tokenAna
$cp06Ok = (($rC.Code -eq 201) -and ($rE.Code -eq 204) -and ($rD.Code -eq 204))
Add-Resultado 'CP-06' 'Operar como rol Miembro (crear/editar/eliminar)' 'comportamiento real 201/204/204' "$($rC.Code)/$($rE.Code)/$($rD.Code)" $cp06Ok 'CONFIRMAR-CON-EQUIPO: si solos Admins, seria FALLO (bug de permisos)'

# ============================================================
Write-Output ''
Write-Output '===== SECCION 2: Creacion ====='

# --- CP-07: Crear presupuesto valido ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatAlim; montoLimite = 300.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenA
$pres = $r.Body | ConvertFrom-Json
$cp07Ok = (($r.Code -eq 201) -and ([double]$pres.montoLimite -eq 300.00) -and ([int]$pres.idHogar -eq $idHogarA))
Add-Resultado 'CP-07' 'Crear presupuesto valido' '201 Created' $r.Code $cp07Ok "id=$($pres.idPresupuesto)"

# --- CP-08: Categoria inexistente ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = 99999; montoLimite = 100.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-08' 'Crear con categoria inexistente' '400 BadRequest' $r.Code ($r.Code -eq 400) $r.Body

# --- CP-09: Categoria de otro hogar ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatB; montoLimite = 100.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-09' 'Crear con categoria de otro hogar' '400 BadRequest' $r.Code ($r.Code -eq 400) $r.Body

# --- CP-10: MontoLimite = 0 ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatSal; montoLimite = 0; mesAnio = '2026-09-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-10' 'Crear con MontoLimite=0' 'comportamiento real: 201' $r.Code ($r.Code -eq 201) 'CONFIRMAR-CON-EQUIPO si el limite debe ser > 0'

# --- CP-11: MontoLimite negativo ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatSal; montoLimite = -50.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-11' 'Crear con MontoLimite negativo' 'comportamiento real: 201' $r.Code ($r.Code -eq 201) 'CONFIRMAR-CON-EQUIPO'

# --- CP-12: Sin MesAnio ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatSal; montoLimite = 120.00 } $tokenA
$mesGuardado = ($r.Body | ConvertFrom-Json).mesAnio
Add-Resultado 'CP-12' 'Crear sin MesAnio' 'comportamiento real: 201 con 0001-01-01' $r.Code (($r.Code -eq 201) -and ($mesGuardado -match '^0001')) "mesAnio=$mesGuardado (CONFIRMAR-CON-EQUIPO si es obligatorio)"

# --- CP-13: Duplicado misma categoria y mes ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatAlim; montoLimite = 301.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-13' 'Crear duplicado (misma categoria y mes)' 'comportamiento real: 201' $r.Code ($r.Code -eq 201) 'CONFIRMAR-CON-EQUIPO si debe ser unico por categoria+mes'

# ============================================================
Write-Output ''
Write-Output '===== SECCION 3: Consulta ====='

# --- CP-14: Listar todos del hogar ---
$r = Invoke-Api 'GET' '/api/Presupuestos' $null $tokenA
$lista = @($r.Body | ConvertFrom-Json | ForEach-Object { $_ })
$soloA = ($lista | Where-Object { [int]$_.idHogar -ne $idHogarA }).Count -eq 0
$meses = @($lista | ForEach-Object { $_.mesAnio })
$ordenDesc = $true
for ($i = 0; $i -lt $meses.Count - 1; $i++) { if ($meses[$i] -lt $meses[$i + 1]) { $ordenDesc = $false } }
Add-Resultado 'CP-14' 'Listar todos los presupuestos del hogar' '200 solo hogar, MesAnio desc' $r.Code (($r.Code -eq 200) -and $soloA -and $ordenDesc -and ($lista.Count -ge 3)) "count=$($lista.Count)"

# --- CP-15: Filtrar por anio y mes ---
$r = Invoke-Api 'GET' '/api/Presupuestos?anio=2026&mes=9' $null $tokenA
$filt9 = @($r.Body | ConvertFrom-Json | ForEach-Object { $_ })
$todosSep = ($filt9 | Where-Object { $_.mesAnio -notmatch '^2026-09' }).Count -eq 0
Add-Resultado 'CP-15' 'Filtrar por anio+mes' '200 solo 2026-09' $r.Code (($r.Code -eq 200) -and $todosSep) "count=$($filt9.Count)"

# --- CP-16: Solo anio (el filtro se ignora) ---
$r = Invoke-Api 'GET' '/api/Presupuestos?anio=2026' $null $tokenA
$soloAnio = @($r.Body | ConvertFrom-Json | ForEach-Object { $_ }).Count
Add-Resultado 'CP-16' 'Filtrar solo por anio' 'comportamiento real: 200 con todos' $r.Code (($r.Code -eq 200) -and ($soloAnio -gt $filt9.Count)) "count=$soloAnio (filtro ignorado; CONFIRMAR-CON-EQUIPO)"

# --- CP-17: Solo mes (el filtro se ignora) ---
$r = Invoke-Api 'GET' '/api/Presupuestos?mes=9' $null $tokenA
$soloMes = @($r.Body | ConvertFrom-Json | ForEach-Object { $_ }).Count
Add-Resultado 'CP-17' 'Filtrar solo por mes' 'comportamiento real: 200 con todos' $r.Code (($r.Code -eq 200) -and ($soloMes -gt $filt9.Count)) "count=$soloMes (filtro ignorado; CONFIRMAR-CON-EQUIPO)"

# --- CP-18: Sin coincidencias ---
$r = Invoke-Api 'GET' '/api/Presupuestos?anio=2027&mes=1' $null $tokenA
$vac = @($r.Body | ConvertFrom-Json | ForEach-Object { $_ }).Count
Add-Resultado 'CP-18' 'Filtrar sin coincidencias' '200 lista vacia' $r.Code (($r.Code -eq 200) -and ($vac -eq 0)) "count=$vac"

# --- CP-19: Por id propio y ajeno ---
$rP = Invoke-Api 'GET' "/api/Presupuestos/$($pres.idPresupuesto)" $null $tokenA
$rAjeno = Invoke-Api 'GET' "/api/Presupuestos/$idPresB" $null $tokenA
Add-Resultado 'CP-19' 'Por id propio y ajeno' '200 propio / 404 ajeno' "$($rP.Code)/$($rAjeno.Code)" (($rP.Code -eq 200) -and ($rAjeno.Code -eq 404)) "propio=$($rP.Code) ajeno=$($rAjeno.Code)"

# ============================================================
Write-Output ''
Write-Output '===== SECCION 4: Edicion ====='

# --- CP-20: Editar monto y mes (Admin) ---
$r = Invoke-Api 'PUT' "/api/Presupuestos/$($pres.idPresupuesto)" @{ idCategoria = $idCatAlim; montoLimite = 250.00; mesAnio = '2026-10-01T00:00:00Z' } $tokenA
$rVer = Invoke-Api 'GET' "/api/Presupuestos/$($pres.idPresupuesto)" $null $tokenA
$editado = $rVer.Body | ConvertFrom-Json
$cp20Ok = (($r.Code -eq 204) -and ([double]$editado.montoLimite -eq 250.00) -and ($editado.mesAnio -match '^2026-10'))
Add-Resultado 'CP-20' 'Editar MontoLimite y MesAnio (Admin)' '204 y cambios verificados' $r.Code $cp20Ok

# --- CP-21: Cambiar a otra categoria del mismo hogar ---
$r = Invoke-Api 'PUT' "/api/Presupuestos/$($pres.idPresupuesto)" @{ idCategoria = $idCatTran; montoLimite = 250.00; mesAnio = '2026-10-01T00:00:00Z' } $tokenA
$rVer = Invoke-Api 'GET' "/api/Presupuestos/$($pres.idPresupuesto)" $null $tokenA
$catNueva = ($rVer.Body | ConvertFrom-Json).idCategoria
Add-Resultado 'CP-21' 'Cambiar a otra categoria del mismo hogar' '204 y categoria actualizada' $r.Code (($r.Code -eq 204) -and ($catNueva -eq $idCatTran)) "idCategoria=$catNueva"

# --- CP-22: Cambiar a categoria de otro hogar ---
$r = Invoke-Api 'PUT' "/api/Presupuestos/$($pres.idPresupuesto)" @{ idCategoria = $idCatB; montoLimite = 250.00; mesAnio = '2026-10-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-22' 'Cambiar a categoria de otro hogar' '400 BadRequest' $r.Code ($r.Code -eq 400) $r.Body

# --- CP-23: Editar presupuesto de otro hogar ---
$r = Invoke-Api 'PUT' "/api/Presupuestos/$idPresB" @{ idCategoria = $idCatB; montoLimite = 1.00; mesAnio = '2026-09-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-23' 'Editar presupuesto de otro hogar' '404 NotFound' $r.Code ($r.Code -eq 404)

# --- CP-24: Editar con MontoLimite 0 y negativo ---
$r = Invoke-Api 'PUT' "/api/Presupuestos/$($pres.idPresupuesto)" @{ idCategoria = $idCatTran; montoLimite = 0; mesAnio = '2026-10-01T00:00:00Z' } $tokenA
$r2 = Invoke-Api 'PUT' "/api/Presupuestos/$($pres.idPresupuesto)" @{ idCategoria = $idCatTran; montoLimite = -10; mesAnio = '2026-10-01T00:00:00Z' } $tokenA
Add-Resultado 'CP-24' 'Editar con MontoLimite 0 / negativo' 'comportamiento real: 204/204' "$($r.Code)/$($r2.Code)" (($r.Code -eq 204) -and ($r2.Code -eq 204)) 'CONFIRMAR-CON-EQUIPO si el limite debe ser > 0'

# ============================================================
Write-Output ''
Write-Output '===== SECCION 5: Eliminacion ====='

# --- CP-25: Eliminar presupuesto propio ---
$r = Invoke-Api 'DELETE' "/api/Presupuestos/$($pres.idPresupuesto)" $null $tokenA
$rVer = Invoke-Api 'GET' "/api/Presupuestos/$($pres.idPresupuesto)" $null $tokenA
Add-Resultado 'CP-25' 'Eliminar presupuesto propio' '204 y 404 al reconsultar' "$($r.Code)/$($rVer.Code)" (($r.Code -eq 204) -and ($rVer.Code -eq 404))

# --- CP-26: Eliminar presupuesto de otro hogar ---
$r = Invoke-Api 'DELETE' "/api/Presupuestos/$idPresB" $null $tokenA
Add-Resultado 'CP-26' 'Eliminar presupuesto de otro hogar' '404 NotFound' $r.Code ($r.Code -eq 404)

# --- CP-27: Eliminar presupuesto inexistente ---
$r = Invoke-Api 'DELETE' '/api/Presupuestos/99999' $null $tokenA
Add-Resultado 'CP-27' 'Eliminar presupuesto inexistente' '404 NotFound' $r.Code ($r.Code -eq 404)

# ============================================================
$resumen = $results | Group-Object Resultado
Write-Output ''
Write-Output '===== RESUMEN ====='
$total = $results.Count
$pasaron = @($results | Where-Object { $_.Resultado -eq 'PASO' }).Count
$fallaron = @($results | Where-Object { $_.Resultado -eq 'FALLO' }).Count
Write-Output "Total: $total | PASARON: $pasaron | FALLARON: $fallaron"

$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'resultados_HU05.csv') -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'resultados_HU05.json') -Encoding UTF8
Write-Output ('Resultados guardados en: ' + (Join-Path $PSScriptRoot 'resultados_HU05.csv'))