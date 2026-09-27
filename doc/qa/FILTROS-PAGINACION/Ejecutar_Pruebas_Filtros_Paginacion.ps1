# ============================================================
# Ejecucion de Casos de Prueba Filtros y Paginacion - RemesaSmart SV
# Prioridad: Media - contra entorno integrado Docker (localhost:8080)
# NOTA: casos de paginacion (FP-13..FP-17) documentan el comportamiento REAL
# (no existe paginacion en el backend); revisar CONFIRMAR-CON-EQUIPO en el diseno.
# ============================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$base = 'http://localhost:8080'
$logFile = Join-Path $PSScriptRoot 'evidencia_raw.log'

$client = [System.Net.Http.HttpClient]::new()
$client.BaseAddress = [Uri]$base
$client.Timeout = [TimeSpan]::FromSeconds(30)
"=== Ejecucion Filtros/Paginacion $(Get-Date -Format s) ===" | Set-Content $logFile

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
    if ($respBody) { ("RespBody: " + $respBody.Substring(0, [Math]::Min(300, $respBody.Length))) | Add-Content $logFile }
    "" | Add-Content $logFile
    @{ Code = [int]$resp.StatusCode; Body = $respBody }
}

function Add-Resultado([string]$Id, [string]$Desc, $Esperado, $Obtenido, [bool]$Pass, [string]$Obs = '') {
    $estado = if ($Pass) { 'PASO' } else { 'FALLO' }
    $results.Add([pscustomobject]@{ ID = $Id; Descripcion = $Desc; Esperado = $Esperado; Obtenido = $Obtenido; Resultado = $estado; Observaciones = $Obs })
    $icon = if ($Pass) { '[PASS]' } else { '[FAIL]' }
    Write-Output ("{0} {1,-7} esperado={2,-22} obtenido={3,-18} {4}" -f $icon, $Id, $Esperado, $Obtenido, $Obs)
}

function New-Lista($Body) { @($Body | ConvertFrom-Json | ForEach-Object { $_ }) }

Write-Output '===== SETUP ====='

# --- Hogar A (Carlos) ---
$sufijo = Get-Random -Minimum 1000 -Maximum 9999
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Carlos FP'; correo = "carlos.fp.$sufijo@demo-test.com"; contrasena = 'Demo1234!'; nombreFamiliar = 'Familia FP' }
if ($r.Code -ne 200) { throw "Falló el registro del Hogar A: $($r.Body)" }
$carlos = $r.Body | ConvertFrom-Json
$tokenA = $carlos.Token
$idHogarA = [int]$carlos.IdHogar
Write-Output "Hogar A: idHogar=$idHogarA"

# --- Categorias Hogar A ---
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Alimentacion'; tipo = 'Gasto'; icono = 'manzana' } $tokenA
$idCatAlim = ($r.Body | ConvertFrom-Json).idCategoria
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Salario'; tipo = 'Ingreso'; icono = 'moneda' } $tokenA
$idCatSal = ($r.Body | ConvertFrom-Json).idCategoria
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Transporte'; tipo = 'Gasto'; icono = 'bus' } $tokenA
$idCatTran = ($r.Body | ConvertFrom-Json).idCategoria
Write-Output "Categorias A: alim=$idCatAlim sal=$idCatSal tran=$idCatTran"

# --- Hogar B (aislamiento) ---
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Marta FP'; correo = "marta.fp.$sufijo@demo-test.com"; contrasena = 'Demo1234!'; nombreFamiliar = 'Familia B FP' }
$marta = $r.Body | ConvertFrom-Json
$tokenB = $marta.Token
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Educacion'; tipo = 'Gasto'; icono = 'libro' } $tokenB
$idCatB = ($r.Body | ConvertFrom-Json).idCategoria
$r = Invoke-Api 'POST' '/api/Movimientos' @{ idCategoria = $idCatB; monto = 999.00; fecha = '2026-01-01T00:00:00Z'; tipo = 'Gasto' } $tokenB
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatB; montoLimite = 500.00; mesAnio = '2026-06-01T00:00:00Z' } $tokenB
Write-Output "Hogar B listo (1 movimiento + 1 presupuesto ajeno)"

# --- 30 movimientos Hogar A ---
for ($i = 1; $i -le 30; $i++) {
    $tipo = if ($i % 2 -eq 0) { 'Gasto' } else { 'Ingreso' }
    $cat = switch ($i % 3) { 0 { $idCatAlim } 1 { $idCatSal } default { $idCatTran } }
    $fecha = ([DateTime]'2026-06-01T00:00:00Z').AddDays($i).ToString('o')
    $r = Invoke-Api 'POST' '/api/Movimientos' @{ idCategoria = $cat; monto = (($i * 13) % 400) + 1.00; fecha = $fecha; tipo = $tipo } $tokenA
    if ($r.Code -ne 201) { throw "Falló crear movimiento $i : $($r.Body)" }
}
Write-Output '30 movimientos sembrados en Hogar A'

# --- 10 presupuestos Hogar A (4 en 2026-09) ---
for ($i = 1; $i -le 10; $i++) {
    $mes = if ($i -le 4) { 9 } elseif ($i -le 7) { 10 } elseif ($i -le 9) { 11 } else { 12 }
    $cat = switch ($i % 3) { 0 { $idCatAlim } 1 { $idCatSal } default { $idCatTran } }
    $r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $cat; montoLimite = (100 + $i * 10) * 1.0; mesAnio = ('2026-{0:D2}-01T00:00:00Z' -f $mes) } $tokenA
    if ($r.Code -ne 201) { throw "Falló crear presupuesto $i : $($r.Body)" }
}
Write-Output '10 presupuestos sembrados en Hogar A'

# --- 3 metas de ahorro Hogar A ---
for ($i = 1; $i -le 3; $i++) {
    $r = Invoke-Api 'POST' '/api/MetasAhorro' @{ titulo = "Meta $i"; montoObjetivo = (500 + $i * 100) * 1.0; fechaLimite = '2026-12-31T00:00:00Z' } $tokenA
    if ($r.Code -ne 201) { throw "Falló crear meta $i : $($r.Body)" }
}
Write-Output '3 metas sembradas en Hogar A'


# ============================================================
Write-Output ''
Write-Output '===== SECCION 1: Filtros de Movimientos ====='

# --- FP-01: lista sin filtros ---
$r = Invoke-Api 'GET' '/api/Movimientos' $null $tokenA
$l = New-Lista $r.Body
$soloA = ($l | Where-Object { [int]$_.idHogar -ne $idHogarA }).Count -eq 0
$fechas = @($l | ForEach-Object { $_.fecha })
$ordenDesc = $true
for ($i = 0; $i -lt $fechas.Count - 1; $i++) { if ($fechas[$i] -lt $fechas[$i + 1]) { $ordenDesc = $false } }
Add-Resultado 'FP-01' 'Listar movimientos sin filtros' '200, 30, solo hogar, fecha desc' "count=$($l.Count) soloA=$soloA orden=$ordenDesc" (($r.Code -eq 200) -and ($l.Count -eq 30) -and $soloA -and $ordenDesc)

# --- FP-02: filtro categoria ---
$r = Invoke-Api 'GET' "/api/Movimientos?categoriaId=$idCatAlim" $null $tokenA
$l = New-Lista $r.Body
$soloCat = ($l | Where-Object { [int]$_.idCategoria -ne $idCatAlim }).Count -eq 0
Add-Resultado 'FP-02' 'Filtrar por categoria' "200, solo cat alim" "count=$($l.Count) soloCat=$soloCat" (($r.Code -eq 200) -and ($l.Count -gt 0) -and $soloCat)

# --- FP-03: categoria inexistente ---
$r = Invoke-Api 'GET' '/api/Movimientos?categoriaId=99999' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-03' 'Filtrar por categoria inexistente' '200 con lista vacia' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 0))

# --- FP-04: filtro tipo ---
$r = Invoke-Api 'GET' '/api/Movimientos?tipo=Gasto' $null $tokenA
$l = New-Lista $r.Body
$soloTipo = ($l | Where-Object { $_.tipo -ne 'Gasto' }).Count -eq 0
Add-Resultado 'FP-04' 'Filtrar por tipo' '200, solo Gasto (15)' "count=$($l.Count) soloTipo=$soloTipo" (($r.Code -eq 200) -and ($l.Count -eq 15) -and $soloTipo)

# --- FP-05: tipo en minusculas ---
$r = Invoke-Api 'GET' '/api/Movimientos?tipo=gasto' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-05' 'Filtrar por tipo en minusculas' 'comportamiento real: vacio' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 0)) 'CONFIRMAR-CON-EQUIPO: comparacion sensible a mayusculas'

# --- FP-06: filtro combinado ---
$r = Invoke-Api 'GET' "/api/Movimientos?categoriaId=$idCatAlim&tipo=Gasto" $null $tokenA
$l = New-Lista $r.Body
$okInterseccion = ($l | Where-Object { [int]$_.idCategoria -ne $idCatAlim -or $_.tipo -ne 'Gasto' }).Count -eq 0
Add-Resultado 'FP-06' 'Filtro combinado categoria+tipo' '200, interseccion' "count=$($l.Count) ok=$okInterseccion" (($r.Code -eq 200) -and ($l.Count -gt 0) -and $okInterseccion)

# --- FP-07: aislamiento por hogar ---
$r = Invoke-Api 'GET' '/api/Movimientos' $null $tokenA
$l = New-Lista $r.Body
$soloHogar = ($l | Where-Object { [int]$_.idHogar -ne $idHogarA }).Count -eq 0
Add-Resultado 'FP-07' 'Aislamiento por hogar (movi ajeno sembrado en B)' '200, solo hogar A' "count=$($l.Count) soloHogar=$soloHogar" (($r.Code -eq 200) -and $soloHogar)

# ============================================================
Write-Output ''
Write-Output '===== SECCION 2: Filtros de Presupuestos ====='

# --- FP-08: anio+mes ---
$r = Invoke-Api 'GET' '/api/Presupuestos?anio=2026&mes=9' $null $tokenA
$l = New-Lista $r.Body
$soloMes = ($l | Where-Object { $_.mesAnio -notmatch '^2026-09' }).Count -eq 0
Add-Resultado 'FP-08' 'Filtrar por anio y mes' '200, solo 2026-09' "count=$($l.Count) soloMes=$soloMes" (($r.Code -eq 200) -and ($l.Count -ge 1) -and $soloMes)

# --- FP-09: solo anio (se ignora) ---
$r = Invoke-Api 'GET' '/api/Presupuestos?anio=2026' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-09' 'Filtrar solo por anio' 'comportamiento real: todos (10)' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 10)) 'CONFIRMAR-CON-EQUIPO: filtro se ignora sin mes'

# --- FP-10: solo mes (se ignora) ---
$r = Invoke-Api 'GET' '/api/Presupuestos?mes=9' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-10' 'Filtrar solo por mes' 'comportamiento real: todos (10)' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 10)) 'CONFIRMAR-CON-EQUIPO: filtro se ignora sin anio'

# --- FP-11: sin coincidencias ---
$r = Invoke-Api 'GET' '/api/Presupuestos?anio=2027&mes=1' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-11' 'Filtrar sin coincidencias' '200, lista vacia' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 0))

# --- FP-12: aislamiento y orden ---
$r = Invoke-Api 'GET' '/api/Presupuestos' $null $tokenA
$l = New-Lista $r.Body
$soloHogar = ($l | Where-Object { [int]$_.idHogar -ne $idHogarA }).Count -eq 0
$meses = @($l | ForEach-Object { $_.mesAnio })
$ordenDesc = $true
for ($i = 0; $i -lt $meses.Count - 1; $i++) { if ($meses[$i] -lt $meses[$i + 1]) { $ordenDesc = $false } }
Add-Resultado 'FP-12' 'Aislamiento por hogar y orden MesAnio desc' '200, 10, solo hogar, desc' "count=$($l.Count) soloHogar=$soloHogar orden=$ordenDesc" (($r.Code -eq 200) -and ($l.Count -eq 10) -and $soloHogar -and $ordenDesc)

# ============================================================
Write-Output ''
Write-Output '===== SECCION 3: Paginacion (comportamiento real) ====='

# --- FP-13: Movimientos con page/pageSize ---
$r = Invoke-Api 'GET' '/api/Movimientos?page=1&pageSize=10' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-13' 'Movimientos con page/pageSize' 'comportamiento real: todos (30)' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 30)) 'CONFIRMAR-CON-EQUIPO: sin paginacion, params ignorados'

# --- FP-14: Presupuestos con page/pageSize ---
$r = Invoke-Api 'GET' '/api/Presupuestos?page=2&pageSize=5' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-14' 'Presupuestos con page/pageSize' 'comportamiento real: todos (10)' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 10)) 'CONFIRMAR-CON-EQUIPO'

# --- FP-15: Categorias con page/pageSize ---
$r = Invoke-Api 'GET' '/api/Categorias?page=1&pageSize=20' $null $tokenA
$l = New-Lista $r.Body
$soloHogar = ($l | Where-Object { [int]$_.idHogar -ne $idHogarA }).Count -eq 0
Add-Resultado 'FP-15' 'Categorias con page/pageSize' 'comportamiento real: todas (3)' "count=$($l.Count) soloHogar=$soloHogar" (($r.Code -eq 200) -and ($l.Count -eq 3) -and $soloHogar) 'CONFIRMAR-CON-EQUIPO'

# --- FP-16: Metas sin paginacion ---
$r = Invoke-Api 'GET' '/api/MetasAhorro' $null $tokenA
$l = New-Lista $r.Body
Add-Resultado 'FP-16' 'Metas de ahorro (3 sembradas)' '200, las 3 completas' "count=$($l.Count)" (($r.Code -eq 200) -and ($l.Count -eq 3)) 'CONFIRMAR-CON-EQUIPO: no hay total/paginas en la respuesta'

# --- FP-17: params invalidos de paginacion ---
$r = Invoke-Api 'GET' '/api/Movimientos?page=-1&pageSize=abc' $null $tokenA
$l = New-Lista $r.Body
$ok = ($r.Code -eq 200) -or ($r.Code -eq 400)
Add-Resultado 'FP-17' 'Params invalidos de paginacion' '200 (todos) o 400 (binding)' "HTTP $($r.Code) count=$($l.Count)" ($ok) 'CONFIRMAR-CON-EQUIPO: no existe contrato de paginacion'

# ============================================================
Write-Output ''
Write-Output '===== RESUMEN ====='
$total = $results.Count
$pasaron = @($results | Where-Object { $_.Resultado -eq 'PASO' }).Count
$fallaron = @($results | Where-Object { $_.Resultado -eq 'FALLO' }).Count
Write-Output "Total: $total | PASARON: $pasaron | FALLARON: $fallaron"

$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'resultados_FILTROS_PAGINACION.csv') -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'resultados_FILTROS_PAGINACION.json') -Encoding UTF8
Write-Output ('Resultados guardados en: ' + (Join-Path $PSScriptRoot 'resultados_FILTROS_PAGINACION.csv'))