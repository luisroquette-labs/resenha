[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Artifact,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Manifest,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$Payload,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$Evidence,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Publisher,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{40}$')][string]$CertificateThumbprint,
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$HostedArtifact
)

$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path $scriptPath -Parent) '../..'))
$windowsRoot = Join-Path $repositoryRoot 'Windows'
$schema = Join-Path $windowsRoot 'release-manifest.schema.json'
$manifestData = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$expectedThumbprint = $CertificateThumbprint.ToUpperInvariant()
$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$resultPath = Join-Path (Split-Path ([IO.Path]::GetFullPath($Manifest)) -Parent) 'verification-current.json'

function Invoke-Checked([scriptblock]$Action, [string]$Failure) {
    & $Action
    if ($LASTEXITCODE) { throw $Failure }
}

function Assert-ReleaseSignature([string]$Path, [bool]$Owned) {
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate) { throw "Invalid Authenticode signature: $Path" }
    if ($Owned -and ($signature.SignerCertificate.Thumbprint -ne $expectedThumbprint -or $signature.SignerCertificate.Subject -notlike "*$Publisher*")) {
        throw "Unexpected publisher certificate: $Path"
    }
    Invoke-Checked { & signtool.exe verify /pa /all /v $Path } "signtool verification failed: $Path"
}

if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') { throw 'Physical Windows x64 is required.' }
if ($manifestData.evidenceClass -ne 'observed' -or $manifestData.sourceCommit -ne $sourceCommit) { throw 'Manifest is not observed evidence for the checked-out source commit.' }
if ($manifestData.signatures.publisher -ne $Publisher -or $manifestData.signatures.certificateThumbprint -ne $expectedThumbprint) { throw 'Expected publisher identity does not match the manifest.' }

$artifactPath = [IO.Path]::GetFullPath($Artifact)
if ((Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifestData.sha256 -or
    (Get-Item -LiteralPath $artifactPath).Length -ne $manifestData.byteLength) { throw 'Installer bytes do not match the manifest.' }

$signatureByPath = @{}
foreach ($item in $manifestData.signatures.items) { $signatureByPath[[string]$item.path] = $item }
Assert-ReleaseSignature $artifactPath $true
Get-ChildItem -LiteralPath $Payload -File -Recurse | Where-Object { $_.Extension -in @('.exe', '.dll') } | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath([IO.Path]::GetFullPath($Payload), $_.FullName).Replace('\', '/')
    if (-not $signatureByPath.ContainsKey($relative)) { throw "PE is absent from signature inventory: $relative" }
    Assert-ReleaseSignature $_.FullName ($signatureByPath[$relative].authority -eq 'release')
}

$defender = Get-MpComputerStatus
if (-not $defender.AntivirusEnabled -or -not $defender.RealTimeProtectionEnabled) { throw 'Microsoft Defender protections are not active.' }
$definitionsUtc = ([DateTime]$defender.AntivirusSignatureLastUpdated).ToUniversalTime()
if ([DateTime]::UtcNow - $definitionsUtc -gt [TimeSpan]::FromHours(24)) { throw 'Microsoft Defender definitions are older than 24 hours.' }
$mpcmd = Get-ChildItem "$env:ProgramData\Microsoft\Windows Defender\Platform" -Filter MpCmdRun.exe -File -Recurse |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if (-not $mpcmd) { throw 'MpCmdRun.exe was not found.' }
Invoke-Checked { & $mpcmd.FullName -Scan -ScanType 3 -File $artifactPath -DisableRemediation } 'Defender installer scan failed or detected a threat.'
Invoke-Checked { & $mpcmd.FullName -Scan -ScanType 3 -File ([IO.Path]::GetFullPath($Payload)) -DisableRemediation } 'Defender payload scan failed or detected a threat.'

$verifierSha = (Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToLowerInvariant()
$arguments = @(
    'run', '--project', 'Resenha.ReleaseVerifier/Resenha.ReleaseVerifier.csproj', '--configuration', 'Release', '--no-build', '--',
    '--manifest', ([IO.Path]::GetFullPath($Manifest)), '--schema', $schema, '--artifact', $artifactPath,
    '--payload', ([IO.Path]::GetFullPath($Payload)), '--evidence', ([IO.Path]::GetFullPath($Evidence)),
    '--source-commit', $sourceCommit, '--publisher', $Publisher, '--certificate-thumbprint', $expectedThumbprint,
    '--verifier-sha256', $verifierSha
)
if ($HostedArtifact) { $arguments += @('--hosted-artifact', ([IO.Path]::GetFullPath($HostedArtifact))) }
Push-Location $windowsRoot
try { $decisionJson = & dotnet @arguments }
finally { Pop-Location }
if ($LASTEXITCODE) { throw "ReleasePolicy rejected the release: $decisionJson" }
$decision = $decisionJson | ConvertFrom-Json
if (-not $decision.contractValid -or -not $decision.candidateReady) { throw 'ReleasePolicy did not approve the signed candidate.' }
if ($manifestData.stage -eq 'hosted-ready' -and -not $decision.canEnablePublicDownload) { throw 'Hosted release is not eligible for the public download.' }

[ordered]@{
    schemaVersion = 1; sourceCommit = $sourceCommit; artifactSha256 = $manifestData.sha256
    verifierSha256 = $verifierSha; verifiedAtUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    defenderDefinitionsUtc = $definitionsUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    contractValid = [bool]$decision.contractValid; candidateReady = [bool]$decision.candidateReady
    hostedReady = [bool]$decision.hostedReady; canEnablePublicDownload = [bool]$decision.canEnablePublicDownload
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultPath -Encoding utf8NoBOM
Write-Host "Release verification PASS: $resultPath"
