param(
    [string]$ResultsDirectory = "$env:TEMP\seguridad-trx"
)

$ErrorActionPreference = "Stop"

$raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$salida = $PSScriptRoot
$csproj = Join-Path $raiz "backend.Tests\backend.Tests.csproj"

New-Item -ItemType Directory -Force -Path $ResultsDirectory | Out-Null
$trx = Join-Path $ResultsDirectory "seguridad.trx"
$consola = Join-Path $ResultsDirectory "consola.txt"

Write-Host "== Ejecutando suite completa (dotnet test) =="
# `dotnet` emite UTF-8, pero PowerShell 5.1 decodifica la salida de un comando nativo con
# la code page de la consola y deja los acentos rotos. Por eso la salida se redirige a un
# archivo (bytes intactos) y se relee como UTF-8. Tampoco se usa Tee-Object: en 5.1 escribe
# UTF-16 (BOM FF FE) y git trataria el log como binario.
# Las rutas absolutas se sustituyen para no versionar el nombre de usuario de quien lo ejecuta.
$log = Join-Path $salida "evidencia_raw.log"
Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
$comando = "dotnet test `"$csproj`" --nologo --logger `"trx;LogFileName=seguridad.trx`" --results-directory `"$ResultsDirectory`" > `"$consola`" 2>&1"
cmd /c $comando | Out-Null
$codigo = $LASTEXITCODE
Get-Content -LiteralPath $consola -Encoding UTF8 |
    Where-Object { $_ -notmatch 'MSB3277|IncludeAtributes' } |
    ForEach-Object {
        $linea = ([string]$_).Replace($raiz, "<repo>").Replace($env:USERPROFILE, "<user>")
        Write-Host $linea
        $linea | Out-File -FilePath $log -Encoding UTF8 -Append
    }
if ($codigo -ne 0) { Write-Warning "dotnet test devolvio el codigo $codigo (revisar el log)." }

[xml]$documento = Get-Content -LiteralPath $trx

# El ambito se etiqueta por clase de test (no por el grupo tematico del
# documento de casos, que reparte 12/10 entre CSRF-Autorizacion y Configuracion).
$area = @{
    "SeguridadJwtTests"           = "Tokens JWT"
    "SeguridadContrasenasTests"   = "Contrasenas"
    "SeguridadAutorizacionTests"  = "CSRF / Autorizacion / IDOR"
    "SeguridadXssTests"           = "XSS"
    "SeguridadConfiguracionTests" = "Headers / Secretos / Pipeline"
}

$resultados = foreach ($prueba in $documento.TestRun.Results.UnitTestResult) {
    $clase = ($prueba.testName -split '\.')[2]
    [pscustomobject]@{
        Suite     = if ($area.ContainsKey($clase)) { "Seguridad" } else { "QA previa" }
        Ambito    = if ($area.ContainsKey($clase)) { $area[$clase] } else { "Suite funcional previa" }
        Caso      = $prueba.testName
        Resultado = if ($prueba.outcome -eq "Passed") { "PASS" } else { "FAIL" }
        Duracion  = $prueba.duration
    }
}

$csv = Join-Path $salida "resultados_SEGURIDAD.csv"
$json = Join-Path $salida "resultados_SEGURIDAD.json"
$resultados | Sort-Object Suite, Caso | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
$resultados | Sort-Object Suite, Caso | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $json -Encoding UTF8

Write-Host ""
Write-Host "== Resumen por suite =="
$resultados | Group-Object Suite, Resultado | Select-Object Name, Count | Format-Table -AutoSize
Write-Host "== Resumen de la suite de seguridad por ambito =="
$resultados | Where-Object Suite -eq "Seguridad" | Group-Object Ambito, Resultado |
    Select-Object Name, Count | Format-Table -AutoSize
Write-Host "Artefactos: $csv , $json , evidencia_raw.log"
