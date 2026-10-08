<#
.SYNOPSIS
  Builds the web app for the real API and packs it for the test server.

.DESCRIPTION
  1. flutter build web --release --no-web-resources-cdn --dart-define=USE_MOCK=false
  2. checks the output: config.json present, <base href="/">, no third-party
     addresses that the browser would call
  3. writes dist\erp-shell-web-<short commit>.zip (build\web without web.config:
     the server keeps its own)

  See docs/deployment.md.

.PARAMETER SkipBuild
  Reuse the existing build\web (check and pack only).

.PARAMETER FailOnWarning
  Exit with code 2 when a check found something (the zip is still written).
#>
[CmdletBinding()]
param(
  [switch]$SkipBuild,
  [switch]$FailOnWarning
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$warnings = New-Object System.Collections.Generic.List[string]

function Write-Step([string]$text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Add-Warning([string]$text) {
  $warnings.Add($text)
  Write-Host "WARNING: $text" -ForegroundColor Yellow
}

# --- 1. build ---------------------------------------------------------------
$web = Join-Path $root 'build\web'
if (-not $SkipBuild) {
  Write-Step 'flutter build web (release, no CDN, USE_MOCK=false)'
  & flutter build web --release --no-web-resources-cdn --dart-define=USE_MOCK=false
  if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit code $LASTEXITCODE)" }
}
if (-not (Test-Path (Join-Path $web 'index.html'))) {
  throw "build\web\index.html not found; run without -SkipBuild"
}

# --- 2. checks --------------------------------------------------------------
Write-Step 'checking the build output'

# config.json is copied into the build and says "real API".
$configPath = Join-Path $web 'config.json'
if (Test-Path $configPath) {
  $config = Get-Content $configPath -Raw | ConvertFrom-Json
  if ($config.useMock -ne $false) { Add-Warning 'config.json: useMock is not false' }
  if ($config.apiBaseUrl -ne '/api/v1') { Add-Warning "config.json: apiBaseUrl is '$($config.apiBaseUrl)', expected '/api/v1'" }
} else {
  Add-Warning 'config.json is missing from the build'
}

# base href must be "/" (path URL strategy, served from the site root).
$index = Get-Content (Join-Path $web 'index.html') -Raw
if ($index -notmatch '<base href="/">') { Add-Warning 'index.html: <base href="/"> not found' }

# Third-party addresses. The Flutter engine contains inert URL literals (docs,
# issue links, and the default gstatic addresses that our config overrides), so
# those are only reported as information. Anything else is a warning.
$inertHosts = @(
  'github.com', 'docs.flutter.dev', 'api.flutter.dev', 'flutter.dev', 'pub.dev',
  'developer.mozilla.org', 'www.w3.org', 'w3.org', 'schema.org', 'dart.dev',
  'tc39.es', 'html.spec.whatwg.org', 'stackoverflow.com', 'goo.gl', 'g.co',
  'www.apache.org', 'localhost'
)
$googleHostPattern = 'gstatic\.com|googleapis\.com|google\.com|googleusercontent\.com|googletagmanager|google-analytics'
$bootstrap = Get-Content (Join-Path $web 'flutter_bootstrap.js') -Raw
$overridden = ($bootstrap -match '"useLocalCanvasKit":true') -and ($bootstrap -match 'fontFallbackBaseUrl:\s*"(?!https?:)')
if (-not $overridden) {
  Add-Warning 'flutter_bootstrap.js: CanvasKit is not local or fontFallbackBaseUrl is not overridden (the engine would download from gstatic)'
}

$files = Get-ChildItem $web -Recurse -File |
  Where-Object { $_.Extension -in '.js', '.html', '.json', '.css', '.map' -and $_.Name -notlike '*.symbols' }
$found = @{}
foreach ($file in $files) {
  $text = [System.IO.File]::ReadAllText($file.FullName)
  foreach ($m in [regex]::Matches($text, 'https?://([A-Za-z0-9.-]+)')) {
    $urlHost = $m.Groups[1].Value.ToLowerInvariant()
    if (-not $found.ContainsKey($urlHost)) { $found[$urlHost] = New-Object System.Collections.Generic.HashSet[string] }
    [void]$found[$urlHost].Add($file.Name)
  }
}
foreach ($urlHost in ($found.Keys | Sort-Object)) {
  $where = ($found[$urlHost] | Sort-Object) -join ', '
  $isInert = $inertHosts | Where-Object { $urlHost -eq $_ -or $urlHost.EndsWith(".$_") }
  if ($isInert) { continue }
  if ($urlHost -match $googleHostPattern -and $overridden) {
    Write-Host "info: $urlHost appears in $where as an engine default that flutter_bootstrap.js overrides (no request is made)"
  } else {
    Add-Warning "external address '$urlHost' in: $where"
  }
}

# --- 3. pack ----------------------------------------------------------------
Write-Step 'packing'
$commit = (& git rev-parse --short HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $commit) { $commit = 'nogit' }
if (& git status --porcelain --untracked-files=no) {
  $commit += '-dirty'
  Add-Warning 'the working tree has uncommitted changes; the zip name ends with -dirty'
}
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist "erp-shell-web-$commit.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
  $prefix = $web.TrimEnd('\') + '\'
  foreach ($file in Get-ChildItem $web -Recurse -File) {
    $relative = $file.FullName.Substring($prefix.Length)
    # The server keeps its own web.config (IIS rules); never ship ours.
    if ($relative -ieq 'web.config') { continue }
    $entryName = $relative.Replace('\', '/')
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName, 'Optimal')
  }
} finally {
  $zip.Dispose()
}

$sizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host ''
Write-Host "Created $zipPath ($sizeMb MB)" -ForegroundColor Green
if ($warnings.Count -gt 0) {
  Write-Host "$($warnings.Count) warning(s) above." -ForegroundColor Yellow
  if ($FailOnWarning) { exit 2 }
}
