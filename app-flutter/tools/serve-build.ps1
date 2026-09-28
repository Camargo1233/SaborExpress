$root = Split-Path -Parent $PSScriptRoot
$webRoot = Join-Path $root 'build\web'
$port = 8088
$address = [System.Net.IPAddress]::Parse('127.0.0.1')
$server = [System.Net.Sockets.TcpListener]::new($address, $port)
$server.Start()

Start-Process "http://127.0.0.1:$port"
Write-Host "Sabor Express aberto em http://127.0.0.1:$port"
Write-Host "Feche esta janela para parar o servidor."

try {
  while ($true) {
    $client = $server.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = [System.IO.StreamReader]::new($stream)
    $requestLine = $reader.ReadLine()

    while ($reader.Peek() -gt -1) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrEmpty($line)) { break }
    }

    $requestPath = 'index.html'
    if ($requestLine -match '^GET\s+([^\s?]+)') {
      $requestPath = [System.Uri]::UnescapeDataString($Matches[1].TrimStart('/'))
      if ([string]::IsNullOrWhiteSpace($requestPath)) {
        $requestPath = 'index.html'
      }
    }

    $filePath = Join-Path $webRoot $requestPath
    if (-not (Test-Path $filePath -PathType Leaf)) {
      $filePath = Join-Path $webRoot 'index.html'
    }

    $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
    $contentType = switch ($extension) {
      '.html' { 'text/html; charset=utf-8' }
      '.js' { 'application/javascript' }
      '.css' { 'text/css' }
      '.json' { 'application/json' }
      '.png' { 'image/png' }
      '.jpg' { 'image/jpeg' }
      '.jpeg' { 'image/jpeg' }
      '.wasm' { 'application/wasm' }
      default { 'application/octet-stream' }
    }

    $body = [System.IO.File]::ReadAllBytes($filePath)
    $headerText = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
    $header = [System.Text.Encoding]::ASCII.GetBytes($headerText)
    $stream.Write($header, 0, $header.Length)
    $stream.Write($body, 0, $body.Length)
    $stream.Close()
    $client.Close()
  }
} finally {
  $server.Stop()
}
