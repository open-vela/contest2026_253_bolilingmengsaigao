$ErrorActionPreference = 'Stop'

$skillDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$repoRoot = (Resolve-Path (Join-Path $skillDir '..\..\..')).Path
$appDir = Join-Path $repoRoot 'quickapp\focusloop'
$rpk = Join-Path $appDir 'dist\com.openvela.focusloop.debug.0.1.0.rpk'

Push-Location $repoRoot
try {
  git diff --check
  if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }

  Get-ChildItem (Join-Path $repoRoot 'scripts') -Filter '*.sh' | ForEach-Object {
    $wslPath = ($_.FullName -replace '^C:', '/mnt/c') -replace '\\', '/'
    wsl.exe -d Ubuntu-22.04 -- bash -n $wslPath
    if ($LASTEXITCODE -ne 0) { throw "Shell syntax check failed: $($_.Name)" }
  }

  Push-Location $appDir
  try {
    npm test
    if ($LASTEXITCODE -ne 0) { throw 'npm test failed' }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'npm run build failed' }
    npm audit --omit=dev
    if ($LASTEXITCODE -ne 0) { throw 'npm audit failed' }
  } finally {
    Pop-Location
  }

  if (-not (Test-Path -LiteralPath $rpk) -or (Get-Item -LiteralPath $rpk).Length -eq 0) {
    throw "RPK missing after build: $rpk"
  }

  $secretHits = rg -l --hidden --glob '!.git/**' --glob '!quickapp/focusloop/node_modules/**' --glob '!quickapp/focusloop/dist/**' 'ghp_[A-Za-z0-9]{20,}|tp-[A-Za-z0-9]{20,}' .
  if ($LASTEXITCODE -eq 0 -and $secretHits) { throw 'Credential-like value found in repository files.' }
  if ($LASTEXITCODE -gt 1) { throw 'Credential scan failed.' }

  $wordingHits = rg -n '模型说成功|90 秒|8\.1 秒|16/16|58 KB' README.md docs --glob '!docs/preview/**' --glob '!docs/screenshots/**'
  if ($LASTEXITCODE -eq 0 -and $wordingHits) {
    $wordingHits | Write-Output
    throw 'Obsolete presentation wording found.'
  }
  if ($LASTEXITCODE -gt 1) { throw 'Wording scan failed.' }

  $size = (Get-Item -LiteralPath $rpk).Length
  Write-Output "FocusLoop verification passed: $rpk ($size bytes)"
} finally {
  Pop-Location
}
