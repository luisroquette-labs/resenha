[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')]
    [string]$Version,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{40}$')]
    [string]$CertificateThumbprint,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]
    [string]$AuthorizationReference,
    [ValidatePattern('^https://')]
    [string]$TimestampUrl = 'https://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path $scriptPath -Parent) '../..'))
$windowsRoot = Join-Path $repositoryRoot 'Windows'
$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$artifactRoot = Join-Path $repositoryRoot "artifacts/windows/$Version/$sourceCommit"
$staging = Join-Path $artifactRoot 'staging'
$payload = Join-Path $artifactRoot 'app'
$reports = Join-Path $artifactRoot 'reports'
$certificateThumbprint = $CertificateThumbprint.ToUpperInvariant()

function Require-Command([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) { throw "Required release tool is missing: $Name" }
    return $command.Source
}

function Invoke-Checked([scriptblock]$Action, [string]$Failure) {
    & $Action
    if ($LASTEXITCODE) { throw $Failure }
}

function Copy-TreeStrict([string]$Source, [string]$Destination) {
    Get-ChildItem -LiteralPath $Source -File -Recurse | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Source, $_.FullName)
        $target = Join-Path $Destination $relative
        $parent = Split-Path $target -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        if (Test-Path -LiteralPath $target) {
            $existing = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            $incoming = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            if ($existing -ne $incoming) { throw "Conflicting published dependency: $relative" }
        } else { Copy-Item -LiteralPath $_.FullName -Destination $target }
    }
}

if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'A physical authorized Windows x64 host is required.'
}
if ((& git -C $repositoryRoot status --porcelain --untracked-files=all).Count -ne 0) {
    throw 'Release source must be clean; commit or remove every change first.'
}
$lock = Get-Content -LiteralPath (Join-Path $windowsRoot 'toolchain-lock.json') -Raw | ConvertFrom-Json
if ($lock.status -ne 'approved-windows-host' -or -not $lock.approvedHostInventory) {
    throw 'The current Windows host has not been inventoried and approved.'
}
if ($lock.approvedHostInventory.authorizationReference -ne $AuthorizationReference) {
    throw 'The supplied host authorization does not match toolchain-lock.json.'
}
$certificate = Get-Item -LiteralPath "Cert:\CurrentUser\My\$certificateThumbprint" -ErrorAction SilentlyContinue
if (-not $certificate -or -not $certificate.HasPrivateKey) {
    throw 'The approved CurrentUser code-signing certificate/private key is unavailable.'
}
if ($certificate.Subject -eq $certificate.Issuer) { throw 'A self-signed certificate cannot create a public release.' }
$chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
$chain.ChainPolicy.RevocationMode = 'Online'
if (-not $chain.Build($certificate)) { throw 'The publisher certificate chain is not trusted.' }

$signtool = Require-Command 'signtool.exe'
$iscc = Require-Command 'ISCC.exe'
if (Test-Path -LiteralPath $artifactRoot) {
    throw 'The immutable artifact directory already exists; use a new version or source commit after preserving evidence.'
}
New-Item -ItemType Directory -Path $artifactRoot, $staging, $payload, $reports -Force | Out-Null
try {
    & (Join-Path $repositoryRoot 'Scripts/windows/preflight.ps1')
    if ($LASTEXITCODE) { throw 'Native preflight failed.' }
    Push-Location $windowsRoot
    try {
        Invoke-Checked { dotnet publish 'Resenha.Windows/Resenha.Windows.csproj' -c Release -r win-x64 --self-contained true --no-restore -p:RuntimeFrameworkVersion=10.0.12 -o (Join-Path $staging 'app') } 'App publish failed.'
        Invoke-Checked { dotnet publish 'Resenha.TargetBroker/Resenha.TargetBroker.csproj' -c Release -r win-x64 --self-contained true --no-restore -p:RuntimeFrameworkVersion=10.0.12 -o (Join-Path $staging 'broker') } 'Target broker publish failed.'
    }
    finally { Pop-Location }
    Copy-TreeStrict (Join-Path $staging 'app') $payload
    Copy-TreeStrict (Join-Path $staging 'broker') $payload

    $nativeSource = Join-Path $windowsRoot 'native/build/windows-x64-cpu/bin/Release'
    $nativeDestination = Join-Path $payload 'native'
    New-Item -ItemType Directory -Path $nativeDestination -Force | Out-Null
    foreach ($file in @('whisper-cli.exe') + @(Get-ChildItem -LiteralPath $nativeSource -Filter '*.dll' | Select-Object -ExpandProperty Name)) {
        Copy-Item -LiteralPath (Join-Path $nativeSource $file) -Destination (Join-Path $nativeDestination $file)
    }
    $licenseDestination = Join-Path $payload 'licenses'
    New-Item -ItemType Directory -Path $licenseDestination -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'LICENSE') -Destination (Join-Path $licenseDestination 'Resenha-MIT.txt')
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'THIRD_PARTY_NOTICES.md') -Destination $licenseDestination
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'Vendor/whisper.cpp/LICENSE') -Destination (Join-Path $licenseDestination 'whisper.cpp-MIT.txt')

    $owned = @(
        'Resenha.exe', 'Resenha.dll', 'Resenha.Core.dll', 'Resenha.Platform.dll',
        'Resenha.TargetBroker.exe', 'Resenha.TargetBroker.dll', 'native/whisper-cli.exe'
    )
    $owned += @(Get-ChildItem -LiteralPath $nativeDestination -Filter '*.dll' | ForEach-Object { "native/$($_.Name)" })
    foreach ($relative in $owned | Sort-Object -Unique) {
        $file = Join-Path $payload $relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Owned release PE is missing: $relative" }
        Invoke-Checked { & $signtool sign /sha1 $certificateThumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 $file } "Signing failed: $relative"
    }

    $signCommand = ('"{0}" sign /sha1 {1} /fd SHA256 /tr {2} /td SHA256 $f' -f $signtool, $certificateThumbprint, $TimestampUrl)
    $installerScript = Join-Path $windowsRoot 'Installer/Resenha.iss'
    Invoke-Checked { & $iscc "/DAppVersion=$Version" "/DPayloadDir=$payload" "/DOutputDir=$artifactRoot" "/Sresenha=$signCommand" $installerScript } 'Inno Setup packaging/signing failed.'
    $installer = Join-Path $artifactRoot "Resenha-$Version-windows-x64-setup.exe"
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'The signed installer was not produced.' }
    Invoke-Checked { & $signtool verify /pa /all /v $installer } 'Installer signature verification failed.'
    $hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($installer))" | Set-Content -LiteralPath "$installer.sha256" -Encoding ascii -NoNewline
    $report = [ordered]@{
        schemaVersion = 1; kind = 'build'; evidenceClass = 'observed'; sourceCommit = $sourceCommit
        artifactSha256 = $hash; recordedAtUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        version = $Version; authorizationReference = $AuthorizationReference
        certificateThumbprint = $certificateThumbprint; timestampUrl = $TimestampUrl
        state = 'signed-candidate-awaiting-defender-and-physical-evidence'
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $reports 'build-observation.json') -Encoding utf8NoBOM
    Write-Host "Signed candidate created but NOT public: $installer"
}
catch {
    if (Test-Path -LiteralPath $artifactRoot) {
        $blocker = [ordered]@{ schemaVersion = 1; sourceCommit = $sourceCommit; version = $Version
            state = 'release-blocked'; observedAtUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
            reason = $_.Exception.Message }
        $blocker | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifactRoot 'RELEASE-BLOCKED.json') -Encoding utf8NoBOM
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
