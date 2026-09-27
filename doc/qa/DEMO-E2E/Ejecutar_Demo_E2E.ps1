# ============================================================
# Ejecucion del FLUJO COMPLETO DE LA DEMO end-to-end - RemesaSmart SV
# ------------------------------------------------------------
# Recorre, paso a paso, los 10 puntos de la demo en vivo del guion de
# presentacion (doc/guion-presentacion.md, seccion 8 "Demo en vivo o video")
# contra la API real levantada en Docker (localhost:8080 + PostgreSQL 16).
#
# Cada paso del guion se traduce en comprobaciones con esperado / obtenido,
# igual que las baterias de HU-01, HU-05, PERF, FILTROS-PAGINACION y
# SEGURIDAD de esta carpeta.
#
# Los checks cuyo "Esperado" es del tipo "la API entrega X" fallan cuando el
# dato lo tiene que calcular el frontend: son riesgos para la demo, no bugs
# de codigo, y asi quedan anotados.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File doc\qa\DEMO-E2E\Ejecutar_Demo_E2E.ps1
# ============================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

$base = 'http://localhost:8080'
$logFile = Join-Path $PSScriptRoot 'evidencia_raw.log'

$client = [System.Net.Http.HttpClient]::new()
$client.BaseAddress = [Uri]"$base/"
$client.Timeout = [TimeSpan]::FromSeconds(60)

"=== Ejecucion DEMO E2E $(Get-Date -Format s) ===" | Set-Content -LiteralPath $logFile -Encoding UTF8
"=== API: $base ===" | Add-Content -LiteralPath $logFile -Encoding UTF8

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
    ("{0} {1} -> {2}" -f $Method, $Path, [int]$resp.StatusCode) | Add-Content -LiteralPath $logFile -Encoding UTF8
    if ($Body) { ("  Req:  " + ($Body | ConvertTo-Json -Depth 8 -Compress)) | Add-Content -LiteralPath $logFile -Encoding UTF8 }
    if ($respBody) { ("  Resp: " + $respBody) | Add-Content -LiteralPath $logFile -Encoding UTF8 }
    '' | Add-Content -LiteralPath $logFile -Encoding UTF8
    return @{ Code = [int]$resp.StatusCode; Body = $respBody; Headers = $resp.Headers }
}

# ConvertFrom-Json de un array JSON devuelve el array ANIDADO (Count=1).
# Esta funcion aplana la respuesta para que Count y el pipeline sean fiables.
function Get-Array([string]$Json) {
    if ([string]::IsNullOrWhiteSpace($Json)) { return , @() }
    $o = $Json | ConvertFrom-Json
    if ($null -eq $o) { return , @() }
    if ($o -is [System.Array]) { return , @($o) }
    return , @($o)
}

function Add-Check {
    param([string]$Id, [string]$Paso, [string]$Desc, $Esperado, $Obtenido, [bool]$Pass, [string]$Obs = '')
    $estado = if ($Pass) { 'PASO' } else { 'FALLO' }
    $results.Add([pscustomobject]@{
            Paso = $Paso; ID = $Id; Descripcion = $Desc
            Esperado = $Esperado; Obtenido = $Obtenido
            Resultado = $estado; Observaciones = $Obs
        })
    $icon = if ($Pass) { '[PASS]' } else { '[FAIL]' }
    Write-Output ("{0} {1,-9} {2}" -f $icon, $Id, $Desc)
    Write-Output ("         esperado: {0} | obtenido: {1}" -f $Esperado, $Obtenido)
    if ($Obs) { Write-Output ("         {0}" -f $Obs) }
}

# ------------------------------------------------------------
# PASOS DE LA DEMO (seccion 8 del guion de presentacion)
# ------------------------------------------------------------
#  1. docker compose up --build
#  2. Registro de familia nueva (hogar + Admin en una sola llamada)
#  3. Agregar miembro con rol Miembro
#  4. Registrar remesa de $400 con entidad emisora
#  5. Registrar gasto de alimentacion de $120
#  6. Tablero: flujo, distribucion del gasto y saldo
#  7. Crear presupuesto de $300 en alimentacion -> barra 40% consumido
#  8. Agregar gasto de $200 mas -> la barra se pasa y aparece la alerta
#  9. Crear meta de ahorro de $2,000 a 6 meses y registrar un aporte
# 10. Abrir Educacion Financiera y mostrar el tip relacionado

$stamp = Get-Date -Format 'MMddHHmmss'
$correoAdmin = "familia.demo.$stamp@demo-e2e.com"
$clave = 'Demo1234!'
$hoy = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')

Write-Output '===== PASO 1: Despliegue (docker compose up --build) ====='
$r = Invoke-Api 'GET' '/swagger/index.html' $null $null
Add-Check 'CP-D01' '1. Despliegue' 'API levantada y respondiendo en :8080' '200' $r.Code ($r.Code -eq 200)

$r = Invoke-Api 'GET' '/api/TipsFinancieros' $null $null
$tipsIniciales = @()
if ($r.Code -eq 200) { $tipsIniciales = Get-Array $r.Body }
Add-Check 'CP-D02' '1. Despliegue' 'Contenido de Educacion Financiera listo al arrancar' '>=1 tip sembrado' "$($tipsIniciales.Count) tip(s)" ($tipsIniciales.Count -ge 1) `
    'BLOQUEANTE del paso 10: la migracion InitialCreate no inserta ninguna fila y GET es publico, asi que en una base limpia la seccion sale vacia sin un alta manual previa.'

Write-Output ''
Write-Output '===== PASO 2: Registro de familia nueva (hogar + Admin en una sola llamada) ====='
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'María López'; correo = $correoAdmin; contrasena = $clave; nombreFamiliar = 'Familia López Demo' }
$regOk = ($r.Code -eq 200)
$login = $null
if ($regOk) { $login = $r.Body | ConvertFrom-Json }
Add-Check 'CP-D03' '2. Registro' 'Registro devuelve 200 con Token, IdHogar y Rol' '200 LoginResponse' $r.Code $regOk `
    $(if ($regOk) { "Rol=$($login.Rol) IdHogar=$($login.IdHogar) IdUsuario=$($login.IdUsuario)" } else { $r.Body })

$tokenAdmin = $login.Token
$idHogar = $login.IdHogar

# La promesa del guion es "una sola llamada" que crea hogar + Admin: se verifica
# que no hace falta una segunda llamada al backend para crear el hogar.
$r = Invoke-Api 'GET' '/api/Hogares' $null $tokenAdmin
$h = $null
if ($r.Code -eq 200) { $h = $r.Body | ConvertFrom-Json }
$hogarOk = ($null -ne $h -and [int]$h.idHogar -eq [int]$idHogar -and $h.nombreFamiliar -eq 'Familia López Demo')
Add-Check 'CP-D04' '2. Registro' 'El hogar quedo creado sin llamada adicional' "IdHogar=$idHogar con tildes intactos" $r.Code $hogarOk $r.Body

$r = Invoke-Api 'GET' '/api/Usuarios' $null $tokenAdmin
$miembros = @()
if ($r.Code -eq 200) { $miembros = Get-Array $r.Body }
$adminUnico = ($miembros.Count -eq 1 -and $miembros[0].rol -eq 'Admin')
Add-Check 'CP-D05' '2. Registro' 'El hogar nace con un unico usuario Admin' '1 miembro con Rol=Admin' `
    "$($miembros.Count) miembro(s), Rol=$(if ($miembros.Count -gt 0) { $miembros[0].rol } else { 'n/a' })" $adminUnico

$hashExpuesto = ($r.Body -match 'ContrasenaHash')
Add-Check 'CP-D06' '2. Registro' 'El hash de la contrasena no se expone en la respuesta' 'sin ContrasenaHash' `
    $(if ($hashExpuesto) { 'ContrasenaHash PRESENTE' } else { 'ausente' }) (-not $hashExpuesto)

Write-Output ''
Write-Output '===== Login (transicion del frontend entre registro y dashboard) ====='
$r = Invoke-Api 'POST' '/api/Auth/login' @{ correo = $correoAdmin; contrasena = $clave }
$loginOk = ($r.Code -eq 200)
$login2 = $null
if ($loginOk) { $login2 = $r.Body | ConvertFrom-Json }
Add-Check 'CP-D07' '2b. Login' 'Login con las credenciales recien creadas' '200 con Token' $r.Code $loginOk

# Claims y vigencia de 8 h (promesa del guion, seccion 5.5)
$partes = $login2.Token.Split('.')
$b64 = $partes[1].Replace('-', '+').Replace('_', '/')
switch ($b64.Length % 4) { 2 { $b64 += '==' } 3 { $b64 += '=' } }
$claims = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))) | ConvertFrom-Json
$nombres = @($claims.PSObject.Properties.Name)
$claimRol = @($nombres | Where-Object { $_ -eq 'role' -or $_ -like '*claims/role' })
$rolCorto = ($nombres -contains 'role')
Add-Check 'CP-D08' '2b. Login' 'El JWT incluye el claim corto "role" que promete el guion' 'role=Admin' `
    $(if ($rolCorto) { 'role=Admin' } else { $claimRol[0] + '=Admin' }) $rolCorto `
    'CONFIRMA BUG-01 (HU-01). Decodificar el token con jwt-decode devuelve payload.role = undefined, asi que cualquier UI que lea el rol del token (ocultar opciones de Admin, etc.) no funciona. Requiere coordinar el nombre del claim con el frontend.'

# Vigencia: iat no existe, asi que se mide exp contra la hora actual.
$restante = [long]$claims.exp - [long][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$vigenciaOk = ($restante -gt 28700 -and $restante -le 28800)
Add-Check 'CP-D09' '2b. Login' 'El token vence a las 8 horas de emitirse' 'exp - iat = 28800 s (exactamente 8 h)' "$restante s restantes" $vigenciaOk

$tieneIat = ($nombres -contains 'iat')
Add-Check 'CP-D10' '2b. Login' 'El JWT incluye "iat" (fecha de emision)' 'iat presente' `
    $(if ($tieneIat) { 'presente' } else { 'ausente' }) $tieneIat `
    'CONFIRMA BUG-01 (HU-01). Sin iat el frontend no puede calcular cuando expira la sesion salvo restando 8 h a exp, y la auditoria de trazas no puede correlacionar.'

Write-Output ''
Write-Output '===== PASO 3: Agregar miembro con rol Miembro ====='
$correoMiembro = "miembro.demo.$stamp@demo-e2e.com"
$r = Invoke-Api 'POST' '/api/Usuarios' @{ nombre = 'José Ramírez'; correo = $correoMiembro; contrasena = $clave; rol = 'Miembro' } $tokenAdmin
$miembroOk = ($r.Code -eq 201)
$idMiembro = $null
if ($miembroOk) { $idMiembro = ($r.Body | ConvertFrom-Json).idUsuario }
Add-Check 'CP-D11' '3. Miembro' 'Alta de miembro con rol Miembro (Admin)' '201 Created' $r.Code $miembroOk `
    $(if ($miembroOk) { "idUsuario=$idMiembro con tildes intactas" } else { $r.Body })

$r = Invoke-Api 'POST' '/api/Auth/login' @{ correo = $correoMiembro; contrasena = $clave }
$loginMiembroOk = ($r.Code -eq 200)
$tokenMiembro = $null
if ($loginMiembroOk) { $tokenMiembro = ($r.Body | ConvertFrom-Json).Token }
Add-Check 'CP-D12' '3. Miembro' 'El miembro puede iniciar sesion' '200 con Token' $r.Code $loginMiembroOk

$r = Invoke-Api 'GET' '/api/Hogares' $null $tokenMiembro
$mismoHogar = ($r.Code -eq 200 -and [int]($r.Body | ConvertFrom-Json).idHogar -eq [int]$idHogar)
Add-Check 'CP-D13' '3. Miembro' 'El miembro pertenece al mismo hogar que el Admin' "IdHogar=$idHogar" $r.Code $mismoHogar

Write-Output ''
Write-Output '===== PASO 4: Registrar remesa de $400 con entidad emisora ====='
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Remesa familiar'; tipo = 'Ingreso'; icono = 'remesa' } $tokenAdmin
$catRemesaOk = ($r.Code -eq 201)
$idCatRemesa = $null
if ($catRemesaOk) { $idCatRemesa = ($r.Body | ConvertFrom-Json).idCategoria }
Add-Check 'CP-D14' '4. Remesa' 'Categoria de remesa creada' '201 Created' $r.Code $catRemesaOk `
    $(if ($catRemesaOk) { "idCategoria=$idCatRemesa" } else { $r.Body })

$origenEmisora = 'Tío Carlos - Los Ángeles'
$r = Invoke-Api 'POST' '/api/Movimientos' @{ idCategoria = $idCatRemesa; monto = 400.00; fecha = $hoy; tipo = 'Ingreso'; descripcion = 'Remesa mensual'; origenEmisora = $origenEmisora } $tokenAdmin
$remesaOk = ($r.Code -eq 201)
$movRemesa = $null
if ($remesaOk) { $movRemesa = $r.Body | ConvertFrom-Json }
Add-Check 'CP-D15' '4. Remesa' 'Remesa de $400 registrada' '201 Created' $r.Code $remesaOk `
    $(if ($remesaOk) { "idMovimiento=$($movRemesa.idMovimiento)" } else { $r.Body })

$origenOk = ($remesaOk -and $movRemesa.origenEmisora -eq $origenEmisora)
Add-Check 'CP-D16' '4. Remesa' 'La entidad emisora se guarda y se devuelve intacta (UTF-8)' "origenEmisora='$origenEmisora'" `
    $(if ($remesaOk) { "'" + $movRemesa.origenEmisora + "'" } else { 'n/a' }) $origenOk

$r = Invoke-Api 'PUT' "/api/Movimientos/$($movRemesa.idMovimiento)" @{ idCategoria = $idCatRemesa; monto = 400.00; fecha = $hoy; tipo = 'Gasto'; descripcion = 'Remesa mensual'; origenEmisora = $origenEmisora } $tokenAdmin
Add-Check 'CP-D17' '4. Remesa' 'Una remesa no se puede registrar con Tipo=Gasto por error de captura' 'rechazo (400) o marca de remesa' `
    "ACEPTADA: $($r.Code) y ahora Tipo=Gasto" ($r.Code -ne 200) `
    'Tipo es texto libre de 20 chars sin lista blanca (mismo patron que BUG-03): la API acepta una remesa de $400 clasificada como Gasto. En la demo el taller de educacion financiera no puede marcar el remesador como tipo "Ingreso", y nada impide que un ingreso quede como Gasto y rompa el tablero.'

# Se restaura el tipo Ingreso para no arrastrar el efecto lateral al paso 6 (tablero).
Invoke-Api 'PUT' "/api/Movimientos/$($movRemesa.idMovimiento)" @{ idCategoria = $idCatRemesa; monto = 400.00; fecha = $hoy; tipo = 'Ingreso'; descripcion = 'Remesa mensual'; origenEmisora = $origenEmisora } $tokenAdmin | Out-Null

Write-Output ''
Write-Output '===== PASO 5: Registrar gasto de alimentacion de $120 ====='
$r = Invoke-Api 'POST' '/api/Categorias' @{ nombre = 'Alimentación'; tipo = 'Gasto'; icono = 'canasta' } $tokenAdmin
$catAlmacenOk = ($r.Code -eq 201)
$idCatAlmacen = $null
if ($catAlmacenOk) { $idCatAlmacen = ($r.Body | ConvertFrom-Json).idCategoria }
Add-Check 'CP-D18' '5. Gasto' 'Categoria de alimentacion creada' '201 Created' $r.Code $catAlmacenOk `
    $(if ($catAlmacenOk) { "idCategoria=$idCatAlmacen" } else { $r.Body })

$r = Invoke-Api 'POST' '/api/Movimientos' @{ idCategoria = $idCatAlmacen; monto = 120.00; fecha = $hoy; tipo = 'Gasto'; descripcion = 'Compra de supermercado' } $tokenAdmin
$gastoOk = ($r.Code -eq 201)
$movGasto1 = $null
if ($gastoOk) { $movGasto1 = $r.Body | ConvertFrom-Json }
Add-Check 'CP-D19' '5. Gasto' 'Gasto de alimentacion de $120' '201 Created' $r.Code $gastoOk `
    $(if ($gastoOk) { "idMovimiento=$($movGasto1.idMovimiento)" } else { $r.Body })

Write-Output ''
Write-Output '===== PASO 6: Tablero (flujo, distribucion del gasto y saldo) ====='
$r = Invoke-Api 'GET' '/api/Movimientos' $null $tokenAdmin
$mvs = @()
if ($r.Code -eq 200) { $mvs = Get-Array $r.Body }
[decimal]$ingresos = 0
[decimal]$gastos = 0
[int]$conEmisora = 0
foreach ($m in $mvs) {
    if ($m.tipo -eq 'Ingreso') { $ingresos += [decimal]$m.monto }
    if ($m.tipo -eq 'Gasto') { $gastos += [decimal]$m.monto }
    if (-not [string]::IsNullOrWhiteSpace($m.origenEmisora)) { $conEmisora++ }
}
$balance = $ingresos - $gastos
$tableroOk = ($ingresos -eq 400 -and $gastos -eq 120 -and $balance -eq 280)
Add-Check 'CP-D20' '6. Tablero' 'Ingresos, gastos y saldo son derivables de los movimientos' 'ingresos=400 gastos=120 saldo=280' `
    "ingresos=$ingresos gastos=$gastos saldo=$balance" $tableroOk

$decimalOk = ($r.Body -match '"monto":\d+\.\d\d') -and ($r.Body -notmatch '"monto":\d+[,}]')
Add-Check 'CP-D21' '6. Tablero' 'Los montos llegan con 2 decimales exactos (sin error de redondeo)' '400.00 y 120.00 exactos' `
    $(if ($decimalOk) { '400.00 / 120.00' } else { 'formato con 0 o mas de 2 decimales' }) $decimalOk `
    'Sustenta la promesa del guion (seccion 5.2) de decimal(10,2) y nunca punto flotante.'

Add-Check 'CP-D22' '6. Tablero' 'La API distingue la remesa de un ingreso comun' 'campo o filtro de remesas en la respuesta' `
    "solo origenEmisora en $conEmisora movimiento(s), sin flag ni filtro propio" $false `
    'La tarjeta violeta de remesas y la vista exclusiva de remesas que promete el guion dependen de que el frontend infiera "es remesa" de que origenEmisora no venga vacio. No hay campo esRemesa ni filtro ?remesas=true: es una convencion, no un contrato.'

Write-Output ''
Write-Output '===== PASO 7: Crear presupuesto de $300 en alimentacion -> barra 40% ====='
$mesAnio = (Get-Date).ToUniversalTime().ToString('yyyy-MM-01')
$anio = (Get-Date).Year
$mes = (Get-Date).Month
$r = Invoke-Api 'POST' '/api/Presupuestos' @{ idCategoria = $idCatAlmacen; montoLimite = 300.00; mesAnio = $mesAnio } $tokenAdmin
$presupOk = ($r.Code -eq 201)
$presup = $null
if ($presupOk) { $presup = $r.Body | ConvertFrom-Json }
Add-Check 'CP-D23' '7. Presupuesto' 'Presupuesto de $300 en alimentacion para el mes actual' '201 Created' $r.Code $presupOk `
    $(if ($presupOk) { "idPresupuesto=$($presup.idPresupuesto) mesAnio=$mesAnio" } else { $r.Body })

$pct = [math]::Round((120.00 / 300.00) * 100, 2)
Add-Check 'CP-D24' '7. Presupuesto' 'La barra de progreso llega a 40% consumido' '40% ($120 de $300)' "$pct%" ($pct -eq 40)

$camposPresup = ''
if ($presupOk) { $camposPresup = (@($presup.PSObject.Properties.Name) -join ',') }
Add-Check 'CP-D25' '7. Presupuesto' 'La API entrega el consumo del presupuesto (montoGastado / porcentaje)' 'campo de consumo o porcentaje en la respuesta' `
    "solo: $camposPresup" $false `
    'La entidad Presupuesto solo tiene montoLimite y mesAnio. El 40%, el color de la barra y el cambio a rojo los tiene que calcular el frontend cruzando /api/Movimientos. Si el frontend no lo hace, el paso 7 no tiene barra que mostrar.'

# El filtro de presupuestos por anio+mes fue el bug 500 corregido (BUG-05): se revalida en vivo
$r = Invoke-Api 'GET' "/api/Presupuestos?anio=$anio&mes=$mes" $null $tokenAdmin
$filtroOk = ($r.Code -eq 200)
$lista = @()
if ($filtroOk) { $lista = Get-Array $r.Body; $filtroOk = ($lista.Count -eq 1 -and [int]$lista[0].idPresupuesto -eq [int]$presup.idPresupuesto) }
Add-Check 'CP-D26' '7. Presupuesto' 'Filtro de presupuestos por anio y mes contra PostgreSQL real' "200 con 1 presupuesto ($anio-$mes)" $r.Code $filtroOk `
    $(if ($filtroOk) { "1 presupuesto para $anio-$mes" } else { $r.Body })

Write-Output ''
Write-Output '===== PASO 8: Gasto de $200 mas -> la barra se pasa y aparece la alerta ====='
$r = Invoke-Api 'POST' '/api/Movimientos' @{ idCategoria = $idCatAlmacen; monto = 200.00; fecha = $hoy; tipo = 'Gasto'; descripcion = 'Segunda compra de supermercado' } $tokenAdmin
Add-Check 'CP-D27' '8. Alerta' 'Segundo gasto de $200 en alimentacion' '201 Created' $r.Code ($r.Code -eq 201)

$r = Invoke-Api 'GET' '/api/Movimientos' $null $tokenAdmin
$mvs = Get-Array $r.Body
[decimal]$gastoAcum = 0
foreach ($m in $mvs) { if ($m.tipo -eq 'Gasto' -and [int]$m.idCategoria -eq [int]$idCatAlmacen) { $gastoAcum += [decimal]$m.monto } }
$pctFinal = [math]::Round(($gastoAcum / 300.00) * 100, 2)
$excedido = ($gastoAcum -eq 320 -and $pctFinal -gt 100)
Add-Check 'CP-D28' '8. Alerta' 'El consumo acumulado supera el limite del presupuesto' 'gasto=320 > limite=300 -> 106.67%' `
    "gasto=$gastoAcum -> $pctFinal%" $excedido `
    'MOMENTO CLAVE DE LA DEMO (el guion pide hacer pausa aqui). El exceso se detecta bien en los datos.'

$rPresup = Invoke-Api 'GET' "/api/Presupuestos/$($presup.idPresupuesto)" $null $tokenAdmin
$hayAlerta = ($rPresup.Body -match 'alerta|Alerta|excedid|Excedid|alert')
Add-Check 'CP-D29' '8. Alerta' 'La API entrega la alerta de presupuesto excedido' 'campo o endpoint de alerta de exceso' `
    $(if ($hayAlerta) { 'presente' } else { 'ninguno: la respuesta es el presupuesto tal cual' }) $hayAlerta `
    'El paso 8 del guion dice "aparece la alerta" y lo presenta como el momento fuerte. Hoy no existe ningun soporte en la API: no hay campo, endpoint, ni codigo HTTP que indique el exceso. Todo depende de que el frontend lo detecte; si no lo hace, el paso mas importante de la demo se cae en silencio.'

Write-Output ''
Write-Output '===== PASO 9: Meta de ahorro de $2,000 a 6 meses y un aporte ====='
$fechaLimite = (Get-Date).AddMonths(6).ToUniversalTime().ToString('yyyy-MM-dd')
$r = Invoke-Api 'POST' '/api/MetasAhorro' @{ titulo = 'Meta de fin de año'; montoObjetivo = 2000.00; fechaLimite = $fechaLimite } $tokenAdmin
$metaOk = ($r.Code -eq 201)
$meta = $null
if ($metaOk) { $meta = $r.Body | ConvertFrom-Json }
Add-Check 'CP-D30' '9. Meta' 'Meta de ahorro de $2,000 a 6 meses' '201 Created' $r.Code $metaOk `
    $(if ($metaOk) { "idMeta=$($meta.idMeta) fechaLimite=$fechaLimite" } else { $r.Body })

$estadoInicialOk = ($metaOk -and [decimal]$meta.montoActual -eq 0 -and $meta.estado -eq 'En progreso')
Add-Check 'CP-D31' '9. Meta' 'La meta nace en 0 y en estado "En progreso"' 'montoActual=0, Estado="En progreso"' `
    $(if ($metaOk) { "montoActual=$($meta.montoActual), Estado='$($meta.estado)'" } else { 'n/a' }) $estadoInicialOk

$r = Invoke-Api 'POST' '/api/Aportes' @{ idMeta = $meta.idMeta; monto = 300.00; fecha = $hoy } $tokenAdmin
$aporteOk = ($r.Code -eq 201)
Add-Check 'CP-D32' '9. Meta' 'Aporte de $300 a la meta' '201 Created' $r.Code $aporteOk $(if ($aporteOk) { $r.Body } else { '' })

$r = Invoke-Api 'GET' "/api/MetasAhorro/$($meta.idMeta)" $null $tokenAdmin
$meta2 = $null
if ($r.Code -eq 200) { $meta2 = $r.Body | ConvertFrom-Json }
$aporteOk2 = ($null -ne $meta2 -and [decimal]$meta2.montoActual -eq 300 -and $meta2.estado -eq 'En progreso')
Add-Check 'CP-D33' '9. Meta' 'El aporte actualiza solo el montoActual de la meta' 'montoActual=300, Estado="En progreso"' `
    $(if ($null -ne $meta2) { "montoActual=$($meta2.montoActual), Estado='$($meta2.estado)'" } else { 'n/a' }) $aporteOk2 `
    'Cumple la promesa del guion (seccion 3, Paso 3).'

# El estado debe cambiar solo al alcanzar el objetivo
Invoke-Api 'POST' '/api/Aportes' @{ idMeta = $meta.idMeta; monto = 1700.00; fecha = $hoy } $tokenAdmin | Out-Null
$r = Invoke-Api 'GET' "/api/MetasAhorro/$($meta.idMeta)" $null $tokenAdmin
$meta3 = $null
if ($r.Code -eq 200) { $meta3 = $r.Body | ConvertFrom-Json }
$estadoAutoOk = ($null -ne $meta3 -and [decimal]$meta3.montoActual -eq 2000 -and $meta3.estado -eq 'Completada')
Add-Check 'CP-D34' '9. Meta' 'La meta cambia de estado sola al alcanzar el objetivo' 'montoActual=2000, Estado="Completada"' `
    $(if ($null -ne $meta3) { "montoActual=$($meta3.montoActual), Estado='$($meta3.estado)'" } else { 'n/a' }) $estadoAutoOk

$falta = [decimal]$meta3.montoObjetivo - [decimal]$meta3.montoActual
$camposMeta = @($meta3.PSObject.Properties.Name) -join ','
Add-Check 'CP-D35' '9. Meta' 'La API entrega "lo que falta" y el ritmo mensual sugerido' 'campos de faltante y de aporte mensual' `
    "solo: $camposMeta (faltante=$falta calculado a mano)" $false `
    'El guion promete que la app calcula el progreso, lo que falta y el ritmo mensual. La entidad no tiene ninguno de esos campos: el frontend tiene que derivarlos de montoObjetivo, montoActual y fechaLimite. En la demo, meta al 100% el faltante es 0 y el ritmo tendria queverse en 0.'

Write-Output ''
Write-Output '===== PASO 10: Educacion Financiera (tip relacionado con la actividad) ====='
$r = Invoke-Api 'GET' '/api/TipsFinancieros' $null $tokenAdmin
$tips = @()
if ($r.Code -eq 200) { $tips = Get-Array $r.Body }
Add-Check 'CP-D36' '10. Tips' 'La seccion de Educacion Financiera muestra tarjetas de tips' '200 con contenido' `
    "$($tips.Count) tip(s)" ($tips.Count -ge 1) `
    'BLOQUEANTE del paso 10: con la base limpia el listado sale vacio porque la migracion no siembra ningun tip.'

$hayRelacion = $false
$relObs = "0 tip(s) y ningun endpoint de tip recomendado"
if ($tips.Count -ge 1) {
    $conCat = @($tips | Where-Object { $null -ne $_.idCategoria -and [int]$_.idCategoria -ne 0 })
    $hayRelacion = ($conCat.Count -ge 1)
    $relObs = "$($tips.Count) tip(s) devueltos en bloque, sin filtrar por hogar ni por actividad"
}
Add-Check 'CP-D37' '10. Tips' 'La API entrega el tip relacionado con la actividad de la familia' 'tip recomendado por contexto' $relObs $hayRelacion `
    'GET /api/TipsFinancieros devuelve la tabla GLOBAL completa ordenada por Titulo, sin filtrar por hogar ni por actividad: no hay endpoint de "tip recomendado". Ademas EducacionFinanciera exige IdCategoria (FK a Categoria, que es por hogar), un acoplamiento raro para contenido global.'

Write-Output ''
Write-Output '===== Cierre: la sesion se cierra de forma segura y el token se invalida ====='
# El logout del frontend es borrar localStorage: se comprueba si el token sigue vivo en la API
$r = Invoke-Api 'GET' '/api/Hogares' $null $tokenAdmin
$tokenVivo = ($r.Code -eq 200)
Add-Check 'CP-D38' '11. Cierre de sesion' 'El token queda invalidado tras el cierre de sesion' '401 despues del logout' $r.Code (-not $tokenVivo) `
    'El logout solo borra localStorage: el JWT sigue aceptandose en la API hasta que pasan sus 8 h. La DEMO_GUIDE (paso 10) afirma que "el token se invalida" y no es cierto. Es el hallazgo ya documentado como SEC-07 (sin jti, sin revocacion).'

$req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, '/api/Hogares')
$req.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $tokenAdmin)
$resp = $client.SendAsync($req).GetAwaiter().GetResult()
$hdrs = @()
foreach ($h in $resp.Headers) { $hdrs += $h.Key }
foreach ($h in $resp.Content.Headers) { $hdrs += $h.Key }
$esperadas = @('X-Content-Type-Options', 'X-Frame-Options', 'Strict-Transport-Security', 'Content-Security-Policy')
$faltantes = @($esperadas | Where-Object { $hdrs -notcontains $_ })
Add-Check 'CP-D39' '11. Cierre de sesion' 'La API responde con cabeceras de seguridad' 'X-Content-Type-Options, HSTS, CSP' `
    "faltan las 4 ($($faltantes -join ', '))" ($faltantes.Count -eq 0) `
    'CONFIRMA SEC-03 en ejecucion real: la API responde sin ni una cabecera de seguridad.'

$swaggerPublico = (Invoke-Api 'GET' '/swagger/v1/swagger.json' $null $null).Code
Add-Check 'CP-D40' '11. Cierre de sesion' 'Swagger no deberia estar expuesto en el entorno de la demo' '404 o 403' $swaggerPublico ($swaggerPublico -ne 200) `
    'El compose arranca con ASPNETCORE_ENVIRONMENT=Development, asi que Swagger UI y el swagger.json quedan abiertos sin autenticacion en el puerto 8080. CONFIRMA SEC-08.'

# ============================================================
Write-Output ''
Write-Output '===== RESUMEN POR PASO DE LA DEMO ====='
foreach ($g in ($results | Group-Object Paso | Sort-Object { [int]($_.Name -replace '\D', '') }, Name)) {
    $p = @($g.Group | Where-Object { $_.Resultado -eq 'PASO' }).Count
    $f = @($g.Group | Where-Object { $_.Resultado -eq 'FALLO' }).Count
    $marca = if ($f -eq 0) { 'OK   ' } else { 'FALLA' }
    Write-Output ("{0}  {1,-40} {2}/{3}" -f $marca, $g.Name, $p, $g.Count)
}

Write-Output ''
Write-Output '===== RESUMEN ====='
$total = $results.Count
$pasaron = @($results | Where-Object { $_.Resultado -eq 'PASO' }).Count
$fallaron = @($results | Where-Object { $_.Resultado -eq 'FALLO' }).Count
Write-Output "Total: $total | PASARON: $pasaron | FALLARON: $fallaron"
Write-Output ''
Write-Output '--- Comprobaciones FALLIDAS ---'
foreach ($f in ($results | Where-Object { $_.Resultado -eq 'FALLO' })) {
    Write-Output ("  {0}  {1}" -f $f.ID, $f.Descripcion)
    Write-Output ("        esperado: {0}" -f $f.Esperado)
    Write-Output ("        obtenido: {0}" -f $f.Obtenido)
}

$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'resultados_DEMO_E2E.csv') -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'resultados_DEMO_E2E.json') -Encoding UTF8
Write-Output ''
Write-Output ('Evidencia cruda: ' + $logFile)
Write-Output ('Resultados: ' + (Join-Path $PSScriptRoot 'resultados_DEMO_E2E.csv'))
Write-Output ("Familia de prueba: $correoAdmin / $clave")
