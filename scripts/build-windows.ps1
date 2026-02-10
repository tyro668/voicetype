$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

flutter build windows --release

$versionMatch = Select-String -Path "$repoRoot/pubspec.yaml" -Pattern '^version:\s*([^\s+]+)'
$version = if ($versionMatch.Matches.Count -gt 0) { $versionMatch.Matches[0].Groups[1].Value } else { "0.0.0" }

$exe = Get-ChildItem "$repoRoot/build/windows" -Recurse -Filter *.exe |
  Where-Object { $_.FullName -match 'runner\\Release' -and $_.Name -notmatch 'flutter_tester' } |
  Select-Object -First 1

if (-not $exe) {
  throw "No Release exe found under build/windows."
}

$outDir = "$repoRoot/build/windows"
$outPath = Join-Path $outDir ("{0}-{1}.exe" -f $exe.BaseName, $version)
Copy-Item $exe.FullName $outPath -Force

Write-Host "EXE created: $outPath"

Pop-Location
