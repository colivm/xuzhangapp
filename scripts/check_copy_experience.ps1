$ErrorActionPreference = 'Stop'

$root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
Set-Location $root

python scripts\copy_lint.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python scripts\playback_copy_lint.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python scripts\life_semantic_regression.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
powershell -ExecutionPolicy Bypass -File scripts\experience_static_check.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output 'Copy experience checks passed.'
