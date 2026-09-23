# ============================================================
# Ejecucion de Casos de Prueba de Performance Basica - RemesaSmart SV
# Prioridad: Media - contra entorno integrado Docker (localhost:8080)
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File Ejecutar_Pruebas_Performance.ps1
#   powershell -ExecutionPolicy Bypass -File Ejecutar_Pruebas_Performance.ps1 -Movimientos 5000 -Repeticiones 3
#
# Requiere base limpia (docker compose down -v && up) y ~30s de espera tras levantar.
# ============================================================
param(
    [int]$Movimientos   = 1000,
    [int]$Presupuestos  = 200,
    [int]$Categorias    = 50,
    [int]$Repeticiones  = 5,
    [int]$UmbralLectura = 500,
    [int]$UmbralVolumenAlto = 1000,
    [int]$UmbralEscritura = 500,
    [int]$UmbralMasivaMs = 90000,
    [string]$Base       = 'http://localhost:8080'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$logFile = Join-Path $PSScriptRoot 'evidencia_raw.log'
$client = [System.Net.Http.HttpClient]::new()
$client.BaseAddress = [Uri]$Base
$client.Timeout = [TimeSpan]::FromSeconds(600)
"=== Ejecucion Performance $(Get-Date -Format s) (Movimientos=$Movimientos, Presupuestos=$Presupuestos, Repeticiones=$Repeticiones) ===" | Set-Content $logFile

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

function Get-Percentil {
    param([double[]]$Datos, [double]$P)
    $indice = [int][math]::Floor($P * ($Datos.Count - 1))
    $Datos[$indice]
}

function Add-Resultado([string]$Id, [string]$Desc, [string]$Estado, $Esperado, $Obtenido, [string]$Obs = '') {
    $results.Add([pscustomobject]@{
        ID = $Id; Descripcion = $Desc; Resultado = $Estado; Esperado = $Esperado; Obtenido = $Obtenido; Observaciones = $Obs
    })
    $icon = switch ($Estado) { 'PASO' { '[PASS]' } 'FALLO' { '[FAIL]' } default { '[-SKIP]' } }
    Write-Output ("{0} {1,-7} esperado={2,-26} obtenido={3,-20} {4}" -f $icon, $Id, $Esperado, $Obtenido, $Obs)
}

function Medir-PromedioP95 {
    param([double[]]$Lat)
    $ordenados = @($Lat | Sort-Object)
    $prom = [math]::Round((($Lat | Measure-Object -Average).Average), 1)
    $p95 = Get-Percentil $ordenados 0.95
    $mediana = $ordenados[[int][math]::Floor(0.5 * ($ordenados.Count - 1))]
    [pscustomobject]@{ Ordenados = $ordenados; Promedio = $prom; P95 = $p95; Mediana = [math]::Round($mediana, 1) }
}

Write-Output '===== SETUP: registro y siembra ====='

# --- Hogar Admin ---
$sufijo = Get-Random -Minimum 1000 -Maximum 9999
$correoSeeds = "perf.seeds.$sufijo@demo-test.com"
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Perf Seeds'; correo = $correoSeeds; contrasena = 'Demo1234!'; nombreFamiliar = 'Familia Perf' }
if ($r.Code -ne 200) { throw "Fallo el registro del hogar: $($r.Body)" }
$perf = $r.Body | ConvertFrom-Json
$token = $perf.Token
$idHogar = [int]$perf.IdHogar
Write-Output "Hogar listo: idHogar=$idHogar"

# --- Categorias (50) ---
$idCats = @()
for ($i = 1; $i -le $Categorias; $i++) {
    $r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = "Categoria $i"; tipo = if ($i % 2 -eq 0) { 'Gasto' } else { 'Ingreso' }; icono = "icono$i" } $token
    if ($r.Code -ne 201) { throw "Fallo crear categoria $i : $($r.Body)" }
    $idCats += [int]($r.Body | ConvertFrom-Json).idCategoria
}
$catGasto = $idCats[0]; $catIngreso = $idCats[1]
Write-Output "Categorias creadas: $($idCats.Count) (gasto=$catGasto, ingreso=$catIngreso)"

# --- Presupuestos (200) ---
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $catGasto; montoLimite = 100.00; mesAnio = '2026-09-01T00:00:00Z' } $token
$idPresBase = [int]($r.Body | ConvertFrom-Json).idPresupuesto
$contadorMes = 0
for ($i = 1; $i -le $Presupuestos; $i++) {
    $contadorMes++
    if ($contadorMes -gt 12) { $contadorMes = 1 }
    $r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCats[$i % $idCats.Count]; montoLimite = (100 + $i) * 1.0; mesAnio = ('2026-{0:D2}-01T00:00:00Z' -f $contadorMes) } $token
    if ($r.Code -ne 201) { throw "Fallo crear presupuesto $i : $($r.Body)" }
}
Write-Output "Presupuestos sembrados: $Presupuestos"

# --- PP-07 + siembra de movimientos (se mide el tiempo global) ---
Write-Output '===== PP-07: creacion masiva de movimientos (siembra) ====='
$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 1; $i -le $Movimientos; $i++) {
    $tipo = if ($i % 2 -eq 0) { 'Gasto' } else { 'Ingreso' }
    $fecha = ([DateTime]'2026-01-01T00:00:00Z').AddMinutes($i).ToString('o')
    $r = Invoke-Api 'POST' '/api/Movimientos' @{ idCategoria = if ($tipo -eq 'Gasto') { $catGasto } else { $catIngreso }; monto = (($i * 7) % 1000) + 0.50; fecha = $fecha; tipo = $tipo; descripcion = "Mov $i"; origenEmisora = 'Banco Perf' } $token
    if ($r.Code -ne 201) { throw "Fallo crear movimiento $i : $($r.Body)" }
}
$sw.Stop()
$pp07Ms = $sw.ElapsedMilliseconds
$pp07Ok = $pp07Ms -lt $UmbralMasivaMs
$estado = if ($pp07Ok) { 'PASO' } else { 'FALLO' }
Add-Resultado 'PP-07' 'Crear movimientos de forma secuencial (siembra)' $estado "global < $($UmbralMasivaMs) ms" "$($pp07Ms) ms ($Movimientos movimientos)" "promedio/op=$([math]::Round($pp07Ms / $Movimientos, 1)) ms"
Write-Output "Siembra de $Movimientos movimientos en $($pp07Ms) ms"

function Medir-Endpoint {
    param([string]$Method, [string]$Path, $Body, [string]$Token)
    $lat = @(); $codigo = $null; $respBody = $null
    for ($i = 0; $i -lt $Repeticiones; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-Api $Method $Path $Body $Token
        $sw.Stop()
        $lat += $sw.ElapsedMilliseconds
        $codigo = $r.Code
        $respBody = $r.Body
    }
    [pscustomobject]@{ Codigo = $codigo; Body = $respBody; Lat = $lat }
}

# ============================================================
Write-Output ''
Write-Output '===== SECCION 1: Consulta (GET) ====='

# --- PP-01: listar movimientos (volumen sembrado) ---
$m = Medir-Endpoint 'GET' '/api/Movimientos' $null $token
$e = Medir-PromedioP95 $m.Lat
$lista01 = @($m.Body | ConvertFrom-Json | ForEach-Object { $_ })
$total01 = $lista01.Count
$paso = (($m.Codigo -eq 200) -and ($total01 -eq $Movimientos) -and ($e.P95 -lt $UmbralLectura))
$estado = if ($paso) { 'PASO' } else { 'FALLO' }
Add-Resultado 'PP-01' 'Listar movimientos (volumen sembrado)' $estado "200, count=$Movimientos, p95 < $($UmbralLectura) ms" "HTTP $($m.Codigo), count=$total01, mediana=$($e.Mediana)ms p95=$($e.P95)ms p99=$(Get-Percentil $e.Ordenados 0.99)ms"

# --- PP-02: filtro categoria + tipo ---
$m = Medir-Endpoint 'GET' "/api/Movimientos?categoriaId=$catGasto&tipo=Gasto" $null $token
$e = Medir-PromedioP95 $m.Lat
$count2 = @($m.Body | ConvertFrom-Json | ForEach-Object { $_ })
$filtroOk = (($count2 | Where-Object { [int]$_.idCategoria -ne $catGasto -or $_.tipo -ne 'Gasto' }).Count -eq 0)
$paso = (($m.Codigo -eq 200) -and ($count2.Count -gt 0) -and $filtroOk -and ($e.P95 -lt $UmbralLectura))
$estado = if ($paso) { 'PASO' } else { 'FALLO' }
Add-Resultado 'PP-02' 'Listar movimientos filtrados por categoria+tipo' $estado "200, solo cat+tipo, p95 < $($UmbralLectura) ms" "HTTP $($m.Codigo), count=$($count2.Count), mediana=$($e.Mediana)ms p95=$($e.P95)ms" "filtro coherente=$filtroOk"

# --- PP-03: filtro presupuestos anio+mes ---
$m = Medir-Endpoint 'GET' '/api/Presupuestos?anio=2026&mes=9' $null $token
$e = Medir-PromedioP95 $m.Lat
$count3 = @($m.Body | ConvertFrom-Json | ForEach-Object { $_ })
$presFiltroOk = (($count3 | Where-Object { $_.mesAnio -notmatch '^2026-09' }).Count -eq 0)
$paso = (($m.Codigo -eq 200) -and $presFiltroOk -and ($e.P95 -lt $UmbralLectura))
$estado = if ($paso) { 'PASO' } else { 'FALLO' }
Add-Resultado 'PP-03' 'Listar presupuestos filtrados anio+mes' $estado '200, solo 2026-09, p95 < 500 ms' "HTTP $($m.Codigo), count=$($count3.Count), mediana=$($e.Mediana)ms p95=$($e.P95)ms" "filtro coherente=$presFiltroOk"

# --- PP-04: listar categorias ---
$m = Medir-Endpoint 'GET' '/api/Categorias' $null $token
$e = Medir-PromedioP95 $m.Lat
$count4 = @($m.Body | ConvertFrom-Json | ForEach-Object { $_ })
$paso = (($m.Codigo -eq 200) -and ($count4.Count -eq $Categorias) -and ($e.P95 -lt 300))
$estado = if ($paso) { 'PASO' } else { 'FALLO' }
Add-Resultado 'PP-04' 'Listar categorias (50 registros)' $estado "200, count=$Categorias, p95 < 300 ms" "HTTP $($m.Codigo), count=$($count4.Count), mediana=$($e.Mediana)ms p95=$($e.P95)ms"

# --- PP-05: volumen alto (solo si Movimientos >= 10000) ---
if ($Movimientos -ge 10000) {
    $m = Medir-Endpoint 'GET' '/api/Movimientos' $null $token
    $e = Medir-PromedioP95 $m.Lat
    $count5 = @($m.Body | ConvertFrom-Json | ForEach-Object { $_ })
    $paso = (($m.Codigo -eq 200) -and ($count5.Count -eq $Movimientos) -and ($e.P95 -lt $UmbralVolumenAlto))
    $estado = if ($paso) { 'PASO' } else { 'FALLO' }
    Add-Resultado 'PP-05' 'Listar movimientos (volumen alto)' $estado "count=$Movimientos, p95 < $($UmbralVolumenAlto) ms" "HTTP $($m.Codigo), count=$($count5.Count), mediana=$($e.Mediana)ms p95=$($e.P95)ms" "SIN paginacion: devuelve todo el set (ver FILTROS-PAGINACION)"
} else {
    Add-Resultado 'PP-05' 'Listar movimientos (volumen alto)' 'SALTADO' "requiere -Movimientos 10000" "-Movimientos=$Movimientos"
}

# ============================================================
Write-Output ''
Write-Output '===== SECCION 2: Escritura y login ====='

# --- PP-06: POST movimiento puntual ---
$m = Medir-Endpoint 'POST' '/api/Movimientos' @{ idCategoria = $catGasto; monto = 1.50; fecha = '2026-12-31T12:00:00Z'; tipo = 'Gasto' } $token
$e = Medir-PromedioP95 $m.Lat
$paso = (($m.Codigo -eq 201) -and ($e.P95 -lt $UmbralEscritura))
$estado = if ($paso) { 'PASO' } else { 'FALLO' }
Add-Resultado 'PP-06' 'Crear movimiento puntual' $estado "201, p95 < $($UmbralEscritura) ms" "HTTP $($m.Codigo), mediana=$($e.Mediana)ms p95=$($e.P95)ms"

# --- PP-08: login ---
$m = Medir-Endpoint 'POST' '/api/Auth/login' @{ correo = $correoSeeds; contrasena = 'Demo1234!' } $null
$e = Medir-PromedioP95 $m.Lat
$paso = (($m.Codigo -eq 200) -and ($e.P95 -lt $UmbralEscritura))
$estado = if ($paso) { 'PASO' } else { 'FALLO' }
Add-Resultado 'PP-08' 'Login con credenciales validas' $estado "200, p95 < $($UmbralEscritura) ms" "HTTP $($m.Codigo), mediana=$($e.Mediana)ms p95=$($e.P95)ms"

# ============================================================
Write-Output ''
Write-Output '===== RESUMEN ====='
$total = $results.Count
$pasaron = @($results | Where-Object { $_.Resultado -eq 'PASO' }).Count
$fallaron = @($results | Where-Object { $_.Resultado -eq 'FALLO' }).Count
$saltados = @($results | Where-Object { $_.Resultado -eq 'SALTADO' }).Count
Write-Output "Total: $total | PASARON: $pasaron | FALLARON: $fallaron | SALTADOS: $saltados"

$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'resultados_PERF.csv') -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'resultados_PERF.json') -Encoding UTF8
Write-Output ('Resultados guardados en: ' + (Join-Path $PSScriptRoot 'resultados_PERF.csv'))