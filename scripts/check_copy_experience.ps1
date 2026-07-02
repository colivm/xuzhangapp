$ErrorActionPreference = 'Stop'

$root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
Set-Location $root

python scripts\copy_lint.py
python scripts\life_semantic_regression.py
powershell -ExecutionPolicy Bypass -File scripts\experience_static_check.ps1

Write-Output 'Copy experience checks passed.'
