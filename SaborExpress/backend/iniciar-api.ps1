# =====================================================================
#  SaborExpress - subir a API do zero no Windows
#  Uso: clique com o botao direito neste arquivo > "Executar com PowerShell"
#       ou, no terminal, dentro da pasta SaborExpress_backend:
#       powershell -ExecutionPolicy Bypass -File .\iniciar-api.ps1
#
#  O script faz, nesta ordem:
#   1. confere se o Node esta instalado
#   2. confere se o servico do PostgreSQL esta rodando (e tenta iniciar)
#   3. cria o banco sabor_express, se ainda nao existir
#   4. cria o arquivo .env, se ainda nao existir
#   5. instala as dependencias e aplica o schema + dados de exemplo
#   6. sobe a API em http://localhost:3000
# =====================================================================

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

function Titulo($texto) {
  Write-Host ""
  Write-Host "== $texto" -ForegroundColor Cyan
}
function Ok($texto)    { Write-Host "   [ok] $texto" -ForegroundColor Green }
function Aviso($texto) { Write-Host "   [!]  $texto" -ForegroundColor Yellow }
function Erro($texto)  { Write-Host "   [x]  $texto" -ForegroundColor Red }

# ---------------------------------------------------------------------
Titulo "1/6  Node.js"
try {
  $versaoNode = (& node --version) 2>$null
  Ok "Node encontrado: $versaoNode"
} catch {
  Erro "Node.js nao encontrado. Instale em https://nodejs.org (versao LTS) e rode este script de novo."
  Read-Host "Pressione Enter para fechar"
  exit 1
}

# ---------------------------------------------------------------------
Titulo "2/6  Servico do PostgreSQL"
$servico = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $servico) {
  Aviso "Nenhum servico 'postgresql*' encontrado nesta maquina."
  Aviso "Se o PostgreSQL estiver instalado, ele pode estar com outro nome. Rode: Get-Service | Where-Object Name -like '*sql*'"
  Aviso "Se nao estiver instalado: https://www.postgresql.org/download/windows/"
  Read-Host "Pressione Enter para fechar"
  exit 1
}

if ($servico.Status -ne 'Running') {
  Aviso "O servico $($servico.Name) esta $($servico.Status). Tentando iniciar..."
  try {
    Start-Service -Name $servico.Name
    Start-Sleep -Seconds 3
    Ok "Servico iniciado."
  } catch {
    Erro "Nao consegui iniciar o servico. Abra o PowerShell COMO ADMINISTRADOR e rode:"
    Write-Host "      Start-Service $($servico.Name)" -ForegroundColor White
    Read-Host "Pressione Enter para fechar"
    exit 1
  }
} else {
  Ok "Servico $($servico.Name) ja esta rodando."
}

# ---------------------------------------------------------------------
Titulo "3/6  Banco de dados"

# Procura o psql.exe nas instalacoes mais comuns
$psql = $null
if (Get-Command psql -ErrorAction SilentlyContinue) {
  $psql = 'psql'
} else {
  foreach ($v in 18, 17, 16, 15, 14, 13) {
    $caminho = "C:\Program Files\PostgreSQL\$v\bin\psql.exe"
    if (Test-Path $caminho) { $psql = $caminho; break }
  }
}

if (-not $psql) {
  Erro "psql.exe nao encontrado. Ele fica em C:\Program Files\PostgreSQL\<versao>\bin\."
  Read-Host "Pressione Enter para fechar"
  exit 1
}
Ok "psql encontrado."

$senhaPostgres = Read-Host "   Senha do usuario 'postgres' (Enter para usar 'postgres')"
if ([string]::IsNullOrWhiteSpace($senhaPostgres)) { $senhaPostgres = 'postgres' }
$env:PGPASSWORD = $senhaPostgres

& $psql -U postgres -h localhost -d postgres -c "select 1;" *> $null
if ($LASTEXITCODE -ne 0) {
  Erro "Nao consegui conectar como 'postgres'. Verifique a senha e tente de novo."
  Read-Host "Pressione Enter para fechar"
  exit 1
}
Ok "Conexao com o PostgreSQL funcionando."

$existe = & $psql -U postgres -h localhost -d postgres -tAc "select 1 from pg_database where datname = 'sabor_express';"
if ($existe -ne '1') {
  & $psql -U postgres -h localhost -d postgres -c "create database sabor_express;" *> $null
  Ok "Banco 'sabor_express' criado."
} else {
  Ok "Banco 'sabor_express' ja existe."
}

# ---------------------------------------------------------------------
Titulo "4/6  Arquivo .env"
if (Test-Path '.env') {
  Ok ".env ja existe (nao foi alterado)."
} else {
  $segredo = -join ((1..64) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
  @"
NODE_ENV=development
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=sabor_express
DB_USER=postgres
DB_PASSWORD=$senhaPostgres
DB_SSL=false

JWT_SECRET=$segredo
JWT_EXPIRES_IN=8h

CORS_ORIGINS=http://localhost:8088,http://127.0.0.1:8088
"@ | Set-Content -Path '.env' -Encoding UTF8
  Ok ".env criado."
}

# ---------------------------------------------------------------------
Titulo "5/6  Dependencias e banco"
if (-not (Test-Path 'node_modules')) {
  Write-Host "   Instalando dependencias (pode demorar um pouco)..."
  & npm install --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) { Erro "npm install falhou."; Read-Host "Enter para fechar"; exit 1 }
}
Ok "Dependencias prontas."

Write-Host "   Aplicando schema e dados de exemplo..."
& npm run db:reset
if ($LASTEXITCODE -ne 0) { Erro "Falha ao aplicar as migrations."; Read-Host "Enter para fechar"; exit 1 }
Ok "Banco populado."

Write-Host "   Rodando os testes automatizados..."
& npm test
if ($LASTEXITCODE -ne 0) { Aviso "Algum teste falhou - a API sobe assim mesmo, mas vale investigar." }

# ---------------------------------------------------------------------
Titulo "6/6  Subindo a API"
Write-Host ""
Write-Host "   API:      http://localhost:3000/api/saude" -ForegroundColor White
Write-Host "   Cardapio: http://localhost:3000/api/restaurantes/sabor-express/produtos" -ForegroundColor White
Write-Host ""
Write-Host "   Login de teste (senha: senha123)" -ForegroundColor White
Write-Host "     gerente@saborexpress.com | garcom@saborexpress.com | cliente@email.com" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   Para parar: Ctrl + C" -ForegroundColor DarkGray
Write-Host ""

Start-Process "http://localhost:3000/api/restaurantes/sabor-express/produtos"
& npm start
