param(
  [string]$FlutterSdk = 'C:\src\flutter',
  [string[]]$TestPaths = @('test/features/pilot_m4_test.dart')
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sdkRoot = (Resolve-Path -LiteralPath $FlutterSdk).Path
$dartRunner = Join-Path $sdkRoot 'bin/cache/dart-sdk/bin/dart.exe'
$toolSnapshot = Join-Path $sdkRoot 'bin/cache/flutter_tools.snapshot'
$toolPackages = Join-Path $sdkRoot 'packages/flutter_tools/.dart_tool/package_config.json'
foreach ($requiredFile in @($dartRunner, $toolSnapshot, $toolPackages)) {
  if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw "Missing Flutter tool file: $requiredFile" }
}

# Direct snapshot execution must use the SDK's package map, not the app's map
# or the absolute paths embedded in a prebuilt SDK snapshot.
$packages = Get-Content -LiteralPath $toolPackages -Raw | ConvertFrom-Json
$testPackage = $packages.packages | Where-Object name -EQ 'test' | Select-Object -First 1
if (-not $testPackage) { throw 'Flutter tool package map is missing package:test.' }
$packageBase = [Uri]::new([IO.Path]::GetFullPath($toolPackages))
$testRoot = [Uri]::new($packageBase, $testPackage.rootUri).LocalPath
if (-not (Test-Path -LiteralPath (Join-Path $testRoot 'lib/src/runner/browser/static/host.dart.js'))) {
  throw 'Flutter browser runner assets are missing; restore the SDK tool dependencies first.'
}

$previousRoot = $env:FLUTTER_ROOT
$previousCi = $env:CI
Push-Location -LiteralPath $projectRoot
try {
  $env:FLUTTER_ROOT = $sdkRoot
  $env:CI = 'true'
  & $dartRunner (Join-Path $PSScriptRoot 'chrome_test_runner.dart') $sdkRoot @TestPaths
  $testExit = $LASTEXITCODE
} finally {
  Pop-Location
  $env:FLUTTER_ROOT = $previousRoot
  $env:CI = $previousCi
}
exit $testExit
