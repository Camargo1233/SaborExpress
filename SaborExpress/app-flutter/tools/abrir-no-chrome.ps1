# =====================================================================
#  SaborExpress - abrir o app Flutter no navegador
#  Coloque este arquivo em SaborExpress\tools\ e rode:
#     powershell -ExecutionPolicy Bypass -File .\tools\abrir-no-chrome.ps1
#  (ou clique com o botao direito > "Executar com PowerShell")
#
#  O script procura o Flutter em tres lugares, nesta ordem:
#     1. flutter no PATH do sistema
#     2. puro:  C:\Users\<voce>\.puro\envs\stable\flutter\bin\flutter.bat
#     3. SDK ao lado do projeto: ..\.flutter-sdk-stable\bin\flutter.bat
# =====================================================================

$ErrorActionPreference = 'Stop'

$raizProjeto = Split-Path -Parent $PSScriptRoot
$pastaAcima  = Split-Path -Parent $raizProjeto
Set-Location -Path $raizProjeto

function Ok($t)    { Write-Host "[ok] $t"  -ForegroundColor Green }
function Aviso($t) { Write-Host "[!]  $t"  -ForegroundColor Yellow }
function Erro($t)  { Write-Host "[x]  $t"  -ForegroundColor Red }

# ---------------------------------------------------------------------
# 1. Localizar o Flutter
# ---------------------------------------------------------------------
$flutter = $null

if (Get-Command flutter -ErrorAction SilentlyContinue) {
  $flutter = 'flutter'
  Ok "Flutter encontrado no PATH."
}

if (-not $flutter) {
  $puro = Join-Path $env:USERPROFILE '.puro\envs\stable\flutter\bin\flutter.bat'
  if (Test-Path $puro) { $flutter = $puro; Ok "Flutter encontrado no puro." }
}

if (-not $flutter) {
  $local = Join-Path $pastaAcima '.flutter-sdk-stable\bin\flutter.bat'
  if (Test-Path $local) { $flutter = $local; Ok "Flutter encontrado ao lado do projeto." }
}

if (-not $flutter) {
  Erro "Nao encontrei o Flutter. Confira o caminho em android\local.properties (flutter.sdk)."
  Read-Host "Pressione Enter para fechar"
  exit 1
}

# ---------------------------------------------------------------------
# 2. Dependencias do projeto
# ---------------------------------------------------------------------
Write-Host ""
Write-Host "Baixando as dependencias do pubspec (flutter pub get)..." -ForegroundColor Cyan
& $flutter pub get
if ($LASTEXITCODE -ne 0) {
  Erro "flutter pub get falhou. Leia a mensagem acima."
  Read-Host "Pressione Enter para fechar"
  exit 1
}

# ---------------------------------------------------------------------
# 3. Escolher o dispositivo web
# ---------------------------------------------------------------------
$dispositivos = & $flutter devices 2>$null | Out-String
$alvo = if ($dispositivos -match 'chrome') { 'chrome' } else { 'web-server' }

if ($alvo -eq 'chrome') {
  Ok "Abrindo no Chrome."
} else {
  Aviso "Chrome nao detectado pelo Flutter. Vou subir um servidor web -"
  Aviso "abra http://127.0.0.1:8088 no navegador quando aparecer a mensagem."
}

Write-Host ""
Write-Host "Enquanto o app roda, no terminal voce pode usar:" -ForegroundColor DarkGray
Write-Host "   r  = recarregar   R = reiniciar   q = sair" -ForegroundColor DarkGray
Write-Host ""

& $flutter run -d $alvo --web-hostname 127.0.0.1 --web-port 8088
