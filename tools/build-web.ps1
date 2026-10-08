<#
.SYNOPSIS
  Builds the web app for the real API and packs it for the test server.

.DESCRIPTION
  1. flutter build web --release --no-web-resources-cdn --dart-define=USE_MOCK=false
  2. renames build files whose names contain [ ] space or % (IIS rejects the
     double-encoded addresses the Flutter engine requests for them), keeping
     FontManifest.json in step
  3. checks the output: config.json present, <base href="/">, no third-party
     addresses, no inline scripts / event handlers in index.html (these are
     errors: the CSP will block them), no unsafe file names
  4. writes dist\erp-shell-web-<short commit>.zip (build\web without web.config:
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
  # A clean output folder: files of earlier builds (renamed assets...) must not leak in.
  if (Test-Path $web) { Remove-Item $web -Recurse -Force }
  & flutter build web --release --no-web-resources-cdn --dart-define=USE_MOCK=false
  if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit code $LASTEXITCODE)" }
}
if (-not (Test-Path (Join-Path $web 'index.html'))) {
  throw "build\web\index.html not found; run without -SkipBuild"
}

# --- 2. file names ----------------------------------------------------------
# Packages may ship assets such as "Geist[wght].ttf" (shadcn_ui, pulled in by
# trina_grid). The engine requests them percent-encoded twice ("%255B"), which
# IIS refuses (404). Rename them and update the font manifest; other manifests
# are not used to load fonts.
Write-Step 'sanitizing file names'
$unsafeName = '[\[\] %]'
$assetsDir = Join-Path $web 'assets'
$fontManifestPath = Join-Path $assetsDir 'FontManifest.json'
function Get-SafeName([string]$name) {
  # The build stores the name percent-encoded (Geist%5Bwght%5D.ttf): decode first.
  $decoded = [uri]::UnescapeDataString($name)
  return ($decoded -replace '\[', '-' -replace '\]', '' -replace ' ', '-' -replace '%', '_')
}
$renamed = 0
foreach ($file in @(Get-ChildItem $web -Recurse -File | Where-Object { $_.Name -match $unsafeName })) {
  $safe = Get-SafeName $file.Name
  $oldRel = $file.FullName.Substring($assetsDir.Length + 1).Replace('\', '/')
  $newRel = $oldRel.Substring(0, $oldRel.Length - $file.Name.Length) + $safe
  Rename-Item -LiteralPath $file.FullName -NewName $safe
  $renamed++
  if (($file.FullName.StartsWith($assetsDir + '\')) -and (Test-Path $fontManifestPath)) {
    $manifest = [System.IO.File]::ReadAllText($fontManifestPath)
    $encodedOld = ($oldRel.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $manifest = $manifest.Replace($encodedOld, $newRel).Replace($oldRel, $newRel)
    [System.IO.File]::WriteAllText($fontManifestPath, $manifest, (New-Object System.Text.UTF8Encoding($false)))
  }
  Write-Host "info: renamed $oldRel -> $newRel"
}
if ($renamed -eq 0) { Write-Host 'no file needed renaming' }

# --- 3. checks --------------------------------------------------------------
Write-Step 'checking the build output'
$errors = New-Object System.Collections.Generic.List[string]
function Add-BuildError([string]$text) {
  $errors.Add($text)
  Write-Host "ERROR: $text" -ForegroundColor Red
}

# Nothing left that IIS would reject, and the font manifest agrees.
foreach ($file in Get-ChildItem $web -Recurse -File | Where-Object { $_.Name -match $unsafeName }) {
  Add-Warning "file name with [ ] space or %: $($file.FullName.Substring($web.Length + 1))"
}
if (Test-Path $fontManifestPath) {
  $manifestText = [System.IO.File]::ReadAllText($fontManifestPath)
  if ($manifestText -match '"asset":"[^"]*(%|\[|\]| )') { Add-Warning 'FontManifest.json: a font asset path still contains %, [ ], or a space' }
  foreach ($m in [regex]::Matches($manifestText, '"asset":"([^"]+)"')) {
    if (-not (Test-Path (Join-Path $assetsDir $m.Groups[1].Value))) {
      Add-Warning "FontManifest.json: font file not found: $($m.Groups[1].Value)"
    }
  }
}

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

# The CSP will block inline scripts and event handler attributes. Scripts must
# be files (web/*.js) loaded with <script src="...">.
$inlineScripts = [regex]::Matches($index, '<script\b(?![^>]*\bsrc\s*=)(?![^>]*\btype\s*=\s*["'']application/(ld\+)?json["''])[^>]*>')
if ($inlineScripts.Count -gt 0) { Add-BuildError "index.html has $($inlineScripts.Count) inline <script> block(s); move them to files under web/" }
$handlers = [regex]::Matches($index, '<[A-Za-z][^>]*\son[a-z]+\s*=')
if ($handlers.Count -gt 0) { Add-BuildError "index.html has $($handlers.Count) inline event handler attribute(s) (onclick= etc.)" }
if ($index -match 'href\s*=\s*["'']\s*javascript:') { Add-BuildError 'index.html has a javascript: URL' }

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

# Errors stop here: a package that the CSP would break is not written.
if ($errors.Count -gt 0) {
  Write-Host "$($errors.Count) error(s); no zip was written." -ForegroundColor Red
  exit 1
}

# --- 4. pack ----------------------------------------------------------------
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
