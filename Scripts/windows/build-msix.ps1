[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('synthetic-smoke', 'store-candidate')]
    [string]$Mode,
    [Parameter(Mandatory)][ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.0$')]
    [string]$Version,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]
    [string]$PayloadDir,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]
    [string]$OutputDir,
    [string]$IdentityName,
    [string]$Publisher,
    [string]$PublisherDisplayName,
    [string]$AuthorizationReference
)

$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path $scriptPath -Parent) '../..'))
$payloadRoot = [IO.Path]::GetFullPath($PayloadDir)
$outputRoot = [IO.Path]::GetFullPath($OutputDir)
$storeRoot = Join-Path $repositoryRoot 'Windows/Store'
$templatePath = Join-Path $storeRoot 'AppxManifest.xml.template'
$assetRoot = Join-Path $storeRoot 'Assets'
$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()

function Invoke-Checked([scriptblock]$Action, [string]$Failure) {
    & $Action
    if ($LASTEXITCODE) { throw $Failure }
}

function Escape-Xml([string]$Value) {
    return [Security.SecurityElement]::Escape($Value)
}

if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'MSIX packaging requires Windows x64.'
}
if (-not (Test-Path -LiteralPath $payloadRoot -PathType Container)) { throw 'Payload directory is missing.' }
foreach ($relative in @('Resenha.exe', 'Resenha.TargetBroker.exe', 'native/whisper-cli.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot $relative) -PathType Leaf)) {
        throw "Required MSIX payload is missing: $relative"
    }
}
foreach ($asset in @('Square44x44Logo.png', 'Square44x44Logo.scale-200.png',
    'Square150x150Logo.png', 'Square150x150Logo.scale-200.png', 'StoreLogo.png', 'StoreLogo.scale-200.png')) {
    if (-not (Test-Path -LiteralPath (Join-Path $assetRoot $asset) -PathType Leaf)) {
        throw "Required MSIX asset is missing: $asset"
    }
}

if ($Mode -eq 'synthetic-smoke') {
    $IdentityName = 'Resenha.SyntheticSmoke'
    $Publisher = 'CN=SYNTHETIC-NOT-A-PUBLISHER'
    $PublisherDisplayName = 'SYNTHETIC TEST ONLY'
} else {
    if ([string]::IsNullOrWhiteSpace($AuthorizationReference)) { throw 'Store candidate authorization reference is required.' }
    foreach ($entry in ([ordered]@{ IdentityName = $IdentityName; Publisher = $Publisher; PublisherDisplayName = $PublisherDisplayName }).GetEnumerator()) {
        if ([string]::IsNullOrWhiteSpace($entry.Value) -or $entry.Value -match '(?i)synthetic|example|placeholder|test only') {
            throw "Partner Center $($entry.Key) is missing or non-production."
        }
    }
    if ($IdentityName -notmatch '^[A-Za-z0-9.-]{3,50}$') { throw 'Partner Center IdentityName format is invalid.' }
    if ($Publisher -notmatch '^CN=.{3,250}$') { throw 'Partner Center Publisher must begin with CN=.' }
    & git -C $repositoryRoot diff --quiet HEAD --
    if ($LASTEXITCODE) { throw 'Store candidate tracked source must match HEAD.' }
    & git -C $repositoryRoot diff --cached --quiet
    if ($LASTEXITCODE) { throw 'Store candidate index must match HEAD.' }
}

$makeAppx = Get-Command 'makeappx.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
if (-not $makeAppx) {
    $kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
    $makeAppx = Get-ChildItem -LiteralPath $kits -Filter 'makeappx.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\makeappx\.exe$' } |
        Sort-Object FullName -Descending | Select-Object -ExpandProperty FullName -First 1
}
if (-not $makeAppx) { throw 'Windows SDK MakeAppx.exe is missing.' }

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$staging = Join-Path $outputRoot 'staging'
$unpacked = Join-Path $outputRoot 'unpacked'
if ((Test-Path -LiteralPath $staging) -or (Test-Path -LiteralPath $unpacked)) {
    throw 'MSIX temporary directories already exist; use a clean output directory.'
}
$baseName = if ($Mode -eq 'synthetic-smoke') {
    "Resenha-$Version-windows-x64-SYNTHETIC-NOT-FOR-SUBMISSION"
} else { "Resenha-$Version-windows-x64-store" }
$packagePath = Join-Path $outputRoot "$baseName.msix"
if (Test-Path -LiteralPath $packagePath) { throw 'Immutable MSIX output already exists.' }

try {
    New-Item -ItemType Directory -Path $staging, (Join-Path $staging 'Assets') -Force | Out-Null
    Copy-Item -Path (Join-Path $payloadRoot '*') -Destination $staging -Recurse -Force
    Copy-Item -Path (Join-Path $assetRoot '*') -Destination (Join-Path $staging 'Assets') -Force
    $manifest = Get-Content -LiteralPath $templatePath -Raw
    $manifest = $manifest.Replace('__IDENTITY_NAME__', (Escape-Xml $IdentityName))
    $manifest = $manifest.Replace('__PUBLISHER__', (Escape-Xml $Publisher))
    $manifest = $manifest.Replace('__VERSION__', $Version)
    $manifest = $manifest.Replace('__PUBLISHER_DISPLAY_NAME__', (Escape-Xml $PublisherDisplayName))
    if ($manifest -match '__[A-Z_]+__') { throw 'MSIX manifest contains unresolved tokens.' }
    [xml]$parsedManifest = $manifest
    $parsedManifest.Save((Join-Path $staging 'AppxManifest.xml'))

    Invoke-Checked { & $makeAppx pack /v /h SHA256 /d $staging /p $packagePath } 'MakeAppx pack failed.'
    New-Item -ItemType Directory -Path $unpacked -Force | Out-Null
    Invoke-Checked { & $makeAppx unpack /v /p $packagePath /d $unpacked } 'MakeAppx unpack validation failed.'
    foreach ($relative in @('AppxManifest.xml', 'Resenha.exe', 'Resenha.TargetBroker.exe',
        'native/whisper-cli.exe', 'Assets/Square44x44Logo.png', 'Assets/Square150x150Logo.png', 'Assets/StoreLogo.png')) {
        if (-not (Test-Path -LiteralPath (Join-Path $unpacked $relative) -PathType Leaf)) {
            throw "Packed MSIX is missing: $relative"
        }
    }
    $hash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($packagePath))" | Set-Content -LiteralPath "$packagePath.sha256" -Encoding ascii -NoNewline
    [ordered]@{
        schemaVersion = 1
        evidenceClass = if ($Mode -eq 'synthetic-smoke') { 'synthetic' } else { 'observed' }
        channel = 'microsoft-store-msix'
        mode = $Mode
        sourceCommit = $sourceCommit
        version = $Version
        filename = [IO.Path]::GetFileName($packagePath)
        sha256 = $hash
        architecture = 'x64'
        identityName = $IdentityName
        publisher = $Publisher
        publisherDisplayName = $PublisherDisplayName
        makeAppx = $makeAppx
        authorizationReference = if ($Mode -eq 'store-candidate') { $AuthorizationReference } else { 'SYNTHETIC-NONE' }
        state = if ($Mode -eq 'store-candidate') { 'candidate-awaiting-partner-center' } else { 'synthetic-never-submit' }
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot "$baseName.json") -Encoding utf8NoBOM
    Write-Host "MSIX package validated: $packagePath"
}
finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    if (Test-Path -LiteralPath $unpacked) { Remove-Item -LiteralPath $unpacked -Recurse -Force }
}
