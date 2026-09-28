$root = Split-Path -Parent $PSScriptRoot
$workspace = Split-Path -Parent $root

$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:APPDATA = $workspace
$env:LOCALAPPDATA = $workspace
$env:PUB_CACHE = Join-Path $workspace '.pub-cache'

& (Join-Path $workspace '.flutter-sdk-stable\bin\flutter.bat') run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8088
