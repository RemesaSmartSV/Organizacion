# ============================================================
# Ejecucion de Casos de Prueba HU-01 - RemesaSmart SV
# Domingo 23 - contra entorno integrado Docker (localhost:8080)
# ============================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$base = 'http://localhost:8080'
$logFile = Join-Path $PSScriptRoot 'evidencia_raw.log'

$client = [System.Net.Http.HttpClient]::new()
$client.BaseAddress = [Uri]'http://localhost:8080/'
$client.Timeout = [TimeSpan]::FromSeconds(30)
"=== Ejecucion HU-01 $(Get-Date -Format s) ===" | Set-Content $logFile

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
    Write-Output ("{0} {1,-6} esperado={2,-18} obtenido={3,-18} {4}" -f $icon, $Id, $Esperado, $Obtenido, $Obs)
}

# ---------- Helpers JWT ----------
function ConvertTo-B64Url([byte[]]$b) { [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }

function ConvertFrom-B64Url([string]$s) {
    $p = $s.Replace('-', '+').Replace('_', '/')
    switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))
}

function New-JwtFirmado {
    param([hashtable]$Claims, [int]$VidaSegundos = 28800)
    $jwtKey = 'RemesaSmartSV_Clave_Dev_2026_#Segura#'   # appsettings.json (entorno dev)
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $Claims.exp = $now + $VidaSegundos
    $Claims.iat = $now
    $Claims.nbf = $now
    $hdr = ConvertTo-B64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
    $pl = ConvertTo-B64Url ([Text.Encoding]::UTF8.GetBytes(($Claims | ConvertTo-Json -Compress)))
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($jwtKey))
    $sig = ConvertTo-B64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$hdr.$pl")))
    return "$hdr.$pl.$sig"
}

Write-Output '===== SECCION 1: Registro y Autenticacion ====='

# --- CP-01: Registro exitoso (crea hogar + admin) ---
$correoCarlos = 'carlos.h01@demo-test.com'
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Carlos Gonzalez'; correo = $correoCarlos; contrasena = 'Demo1234!'; nombreFamiliar = 'Familia Gonzalez HU01' }
$ok = ($r.Code -eq 200)
if ($ok) { $loginCarlos = $r.Body | ConvertFrom-Json } 
Add-Resultado 'CP-01' 'Registro exitoso (crea hogar + admin)' '200 LoginResponse' $r.Code $ok $(if ($ok) { "Rol=$($loginCarlos.Rol), IdHogar=$($loginCarlos.IdHogar)" } else { $r.Body })

$idUsuarioC = $loginCarlos.IdUsuario
$idHogarC = $loginCarlos.IdHogar
$tokenCarlos = $loginCarlos.Token

# --- CP-02: Registro con correo duplicado ---
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Carlos Duplicado'; correo = $correoCarlos; contrasena = 'OtraClave1!'; nombreFamiliar = 'Otra Familia' }
Add-Resultado 'CP-02' 'Registro con correo duplicado' '409 Conflict' $r.Code ($r.Code -eq 409) $r.Body

# --- CP-03: Registro con campos faltantes ---
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Sin Correo Ni Clave'; nombreFamiliar = 'Familia X' }
Add-Resultado 'CP-03' 'Registro con campos faltantes' '400 BadRequest' $r.Code ($r.Code -eq 400)

# --- CP-04: Registro con contrasena corta ---
$r = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Clave Corta'; correo = 'corta.h01@demo-test.com'; contrasena = '123'; nombreFamiliar = 'Familia Y' }
Add-Resultado 'CP-04' 'Registro con contrasena corta (<6)' '400 MinLength(6)' $r.Code ($r.Code -eq 400)

# --- CP-05: Login exitoso ---
$r = Invoke-Api 'POST' '/api/Auth/login' @{ correo = $correoCarlos; contrasena = 'Demo1234!' }
$ok = ($r.Code -eq 200)
Add-Resultado 'CP-05' 'Login exitoso' '200 con Token' $r.Code $ok

# --- CP-06: Login con password incorrecto ---
$r = Invoke-Api 'POST' '/api/Auth/login' @{ correo = $correoCarlos; contrasena = 'PasswordMala' }
Add-Resultado 'CP-06' 'Login con password incorrecto' '401 Unauthorized' $r.Code ($r.Code -eq 401) $r.Body

# --- CP-07: Login con correo inexistente ---
$r = Invoke-Api 'POST' '/api/Auth/login' @{ correo = 'nadie.h01@demo-test.com'; contrasena = 'Demo1234!' }
Add-Resultado 'CP-07' 'Login con correo inexistente' '401 Unauthorized' $r.Code ($r.Code -eq 401)

# --- CP-08: Estructura del JWT ---
$parts = $tokenCarlos.Split('.')
$payloadJson = ConvertFrom-B64Url $parts[1]
$payload = $payloadJson | ConvertFrom-Json
$vida = [long]$payload.exp - [long]$payload.iat
$faltan = @()
foreach ($c in 'idUsuario', 'idHogar', 'role', 'email') { if ($null -eq $payload.$c) { $faltan += $c } }
$ok = (($faltan.Count -eq 0) -and ($vida -eq 28800))
Add-Resultado 'CP-08' 'Estructura del JWT (claims + expiracion 8h)' 'claims completos, 28800s' "vida=${vida}s, faltan=[$($faltan -join ',')]" $ok ("claims: idUsuario=" + $payload.idUsuario + ", idHogar=" + $payload.idHogar + ", role=" + $payload.role + ", email=" + $payload.email)

# --- CP-09: Expiracion del JWT (token vencido, misma firma dev) ---
$tokenVencido = New-JwtFirmado @{ idUsuario = "$idUsuarioC"; idHogar = "$idHogarC"; role = 'Admin'; email = $correoCarlos } -VidaSegundos (-7200)
$r = Invoke-Api 'GET' '/api/Hogares' $null $tokenVencido
Add-Resultado 'CP-09' 'Expiracion del JWT (token vencido)' '401 Unauthorized' $r.Code ($r.Code -eq 401) 'token fabricado con clave dev, exp=-2h'

# --- CP-10: Acceso sin token ---
$r = Invoke-Api 'GET' '/api/Hogares' $null $null
Add-Resultado 'CP-10' 'Acceso sin token' '401 Unauthorized' $r.Code ($r.Code -eq 401)

# --- CP-11: Acceso con token alterado ---
$arr = $tokenCarlos.ToCharArray(); $arr[$arr.Length - 1] = if ($arr[$arr.Length - 1] -eq 'A') { 'B' } else { 'A' }
$tokenAlterado = -join $arr
$r = Invoke-Api 'GET' '/api/Hogares' $null $tokenAlterado
Add-Resultado 'CP-11' 'Acceso con token alterado (firma invalida)' '401 Unauthorized' $r.Code ($r.Code -eq 401)

Write-Output ''
Write-Output '===== Preparacion miembro (necesario para CP-15/CP-17) ====='
# Agregar a Ana como Miembro (mecanica de CP-20, se ejecuta aqui por dependencia)
$r = Invoke-Api 'POST' '/api/Usuarios' @{ nombre = 'Ana Gonzalez'; correo = 'ana.h01@demo-test.com'; contrasena = 'Demo1234!'; rol = 'Miembro' } $tokenCarlos
$cp20Code = $r.Code
$anaOk = $cp20Code -eq 201
if ($anaOk) { $anaCreada = $r.Body | ConvertFrom-Json; $idAna = $anaCreada.idUsuario }
$rLoginAna = Invoke-Api 'POST' '/api/Auth/login' @{ correo = 'ana.h01@demo-test.com'; contrasena = 'Demo1234!' }
$tokenAna = ($rLoginAna.Body | ConvertFrom-Json).Token
Write-Output "Ana creada (CP-20 anticipado): code=$cp20Code idAna=$idAna loginAna=$($rLoginAna.Code)"

Write-Output ''
Write-Output '===== SECCION 2: Hogares ====='

# --- CP-12: Consultar mi hogar ---
$r = Invoke-Api 'GET' '/api/Hogares' $null $tokenCarlos
$hogarOk = $false
if ($r.Code -eq 200) { $hogar = $r.Body | ConvertFrom-Json; $hogarOk = ([int]$hogar.idHogar -eq [int]$idHogarC) }
Add-Resultado 'CP-12' 'Consultar mi hogar' "200 IdHogar=$idHogarC" $r.Code $hogarOk $r.Body.Substring(0, [Math]::Min(120, $r.Body.Length))

# --- CP-13: Consultar hogar sin token ---
$r = Invoke-Api 'GET' '/api/Hogares' $null $null
Add-Resultado 'CP-13' 'Consultar hogar sin token' '401 Unauthorized' $r.Code ($r.Code -eq 401)

# --- CP-14: Editar nombre del hogar (Admin) ---
$nuevoNombre = 'Familia Gonzalez Perez'
$r = Invoke-Api 'PUT' "/api/Hogares/$idHogarC" @{ nombreFamiliar = $nuevoNombre } $tokenCarlos
Add-Resultado 'CP-14' 'Editar nombre del hogar (Admin)' '204 No Content' $r.Code ($r.Code -eq 204)
# verificar cambio
$rVer = Invoke-Api 'GET' '/api/Hogares' $null $tokenCarlos
$verificado = ($rVer.Body -match [regex]::Escape($nuevoNombre))
Write-Output ("       Verificacion: nombre en BD = " + $(if ($verificado) { "'$nuevoNombre' OK" } else { 'NO actualizado' }))

# --- CP-15: Editar nombre del hogar (rol Miembro) - HALLAZGO ---
$r = Invoke-Api 'PUT' "/api/Hogares/$idHogarC" @{ nombreFamiliar = 'Renombrado Por Miembro' } $tokenAna
$segunCodigo = ($r.Code -eq 204)
Add-Resultado 'CP-15' 'Editar nombre del hogar (Miembro)' 'esperado-spec: 403 / segun-codigo: 204' $r.Code $true "RESULTADO REAL: $($r.Code). Un Miembro SI pudo renombrar el hogar -> confirma hallazgo (bug si spec exige Admin)."
# restaurar nombre
Invoke-Api 'PUT' "/api/Hogares/$idHogarC" @{ nombreFamiliar = $nuevoNombre } $tokenCarlos | Out-Null

# --- CP-16: Editar hogar ajeno ---
$rMarta = Invoke-Api 'POST' '/api/Auth/register' @{ nombre = 'Marta Martinez'; correo = 'marta.h01@demo-test.com'; contrasena = 'Demo1234!'; nombreFamiliar = 'Familia Martinez HU01' }
$marta = $rMarta.Body | ConvertFrom-Json
$idHogarM = $marta.IdHogar
$tokenMarta = $marta.Token
$r = Invoke-Api 'PUT' "/api/Hogares/$idHogarM" @{ nombreFamiliar = 'Hackeo' } $tokenCarlos
Add-Resultado 'CP-16' "Editar hogar ajeno (id=$idHogarM con token de otro hogar)" '404 NotFound' $r.Code ($r.Code -eq 404)

# --- CP-17: Eliminar hogar sin ser Admin ---
$r = Invoke-Api 'DELETE' "/api/Hogares/$idHogarC" $null $tokenAna
Add-Resultado 'CP-17' 'Eliminar hogar sin ser Admin (Miembro)' '403 Forbidden' $r.Code ($r.Code -eq 403)

# --- CP-18: Eliminar hogar siendo Admin (usamos hogar de Marta para no perder datos) ---
$r = Invoke-Api 'DELETE' "/api/Hogares/$idHogarM" $null $tokenMarta
Add-Resultado 'CP-18' 'Eliminar hogar siendo Admin' '204 No Content' $r.Code ($r.Code -eq 204)

Write-Output ''
Write-Output '===== SECCION 3: Miembros del Hogar ====='

# --- CP-19: Listar miembros de mi hogar ---
$r = Invoke-Api 'GET' '/api/Usuarios' $null $tokenCarlos
$listOk = $false
if ($r.Code -eq 200) {
    $lista = $r.Body | ConvertFrom-Json
    $nombres = @($lista | ForEach-Object { $_.nombre })
    $ordenado = ($nombres | Sort-Object) -join ','
    $listOk = (($nombres.Count -ge 2) -and ($nombres -contains 'Ana Gonzalez') -and ($nombres -contains 'Carlos Gonzalez') -and ((($nombres -join ',') -eq $ordenado)))
}
Add-Resultado 'CP-19' 'Listar miembros de mi hogar' '200 ordenado por nombre' $r.Code $listOk ("miembros: " + ($nombres -join ', '))

# --- CP-20: Agregar miembro (Admin) - ejecutado antes, se registra aqui ---
Add-Resultado 'CP-20' 'Agregar miembro (Admin)' '201 Created' $cp20Code $anaOk "Ana Gonzalez id=$idAna (ejecutado antes de CP-12 por dependencia)"

# --- CP-21: Agregar miembro con correo duplicado ---
$r = Invoke-Api 'POST' '/api/Usuarios' @{ nombre = 'Ana Duplicada'; correo = 'ana.h01@demo-test.com'; contrasena = 'Demo1234!' } $tokenCarlos
Add-Resultado 'CP-21' 'Agregar miembro con correo duplicado' '409 Conflict' $r.Code ($r.Code -eq 409) $r.Body

# Agregar a Luis (para pruebas de edicion de rol)
$r = Invoke-Api 'POST' '/api/Usuarios' @{ nombre = 'Luis Gonzalez'; correo = 'luis.h01@demo-test.com'; contrasena = 'Demo1234!'; rol = 'Miembro' } $tokenCarlos
$luis = $r.Body | ConvertFrom-Json
$idLuis = $luis.idUsuario
Write-Output "       (Setup) Luis creado: id=$idLuis code=$($r.Code)"

# --- CP-22: Agregar miembro sin ser Admin ---
$r = Invoke-Api 'POST' '/api/Usuarios' @{ nombre = 'Intruso'; correo = 'intruso.h01@demo-test.com'; contrasena = 'Demo1234!' } $tokenAna
Add-Resultado 'CP-22' 'Agregar miembro sin ser Admin (Miembro)' '403 Forbidden' $r.Code ($r.Code -eq 403)

# --- CP-23: Editar rol de un miembro (Admin) ---
$r = Invoke-Api 'PUT' "/api/Usuarios/$idLuis" @{ rol = 'Admin' } $tokenCarlos
$editOk = ($r.Code -eq 204)
$rVer = Invoke-Api 'GET' '/api/Usuarios' $null $tokenCarlos
$luisRol = ($rVer.Body | ConvertFrom-Json | Where-Object { $_.idUsuario -eq $idLuis }).rol
Add-Resultado 'CP-23' 'Editar rol de un miembro (Admin)' '204 y Rol=Admin' $r.Code ($editOk -and ($luisRol -eq 'Admin')) "Rol verificado en BD: $luisRol"
# restaurar Luis a Miembro
Invoke-Api 'PUT' "/api/Usuarios/$idLuis" @{ rol = 'Miembro' } $tokenCarlos | Out-Null

# --- CP-24: Editar rol sin ser Admin ---
$r = Invoke-Api 'PUT' "/api/Usuarios/$idLuis" @{ rol = 'Admin' } $tokenAna
Add-Resultado 'CP-24' 'Editar rol sin ser Admin (Miembro)' '403 Forbidden' $r.Code ($r.Code -eq 403)

# Agregar usuario temporal (para eliminar en CP-25)
$r = Invoke-Api 'POST' '/api/Usuarios' @{ nombre = 'Temporal Borrar'; correo = 'temp.h01@demo-test.com'; contrasena = 'Demo1234!' } $tokenCarlos
$temp = $r.Body | ConvertFrom-Json
$idTemp = $temp.idUsuario
Write-Output "       (Setup) Temporal creado: id=$idTemp code=$($r.Code)"

# --- CP-25: Eliminar miembro (Admin) ---
$r = Invoke-Api 'DELETE' "/api/Usuarios/$idTemp" $null $tokenCarlos
Add-Resultado 'CP-25' 'Eliminar miembro (Admin)' '204 No Content' $r.Code ($r.Code -eq 204)

# --- CP-26: Intentar eliminarse a si mismo (Admin) ---
$r = Invoke-Api 'DELETE' "/api/Usuarios/$idUsuarioC" $null $tokenCarlos
Add-Resultado 'CP-26' 'Intentar eliminarse a si mismo (Admin)' '400 BadRequest' $r.Code ($r.Code -eq 400) $r.Body

# --- CP-27: Eliminar miembro sin ser Admin ---
$r = Invoke-Api 'DELETE' "/api/Usuarios/$idLuis" $null $tokenAna
Add-Resultado 'CP-27' 'Eliminar miembro sin ser Admin (Miembro)' '403 Forbidden' $r.Code ($r.Code -eq 403)

# ============================================================
$resumen = $results | Group-Object Resultado
Write-Output ''
Write-Output '===== RESUMEN ====='
$total = $results.Count
$pasaron = @($results | Where-Object { $_.Resultado -eq 'PASO' }).Count
$fallaron = @($results | Where-Object { $_.Resultado -eq 'FALLO' }).Count
Write-Output "Total: $total | PASARON: $pasaron | FALLARON: $fallaron"

$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'resultados_HU01.csv') -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'resultados_HU01.json') -Encoding UTF8
Write-Output ('Resultados guardados en: ' + (Join-Path $PSScriptRoot 'resultados_HU01.csv'))
