[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('windows10', 'windows11')][string]$Target,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Artifact,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Model,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Checklist,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$AuthorizationReference,
    [Parameter(Mandatory)][ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')][string]$Version,
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath (Split-Path $_ -Parent) -PathType Container })][string]$Output
)

$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path $scriptPath -Parent) '../..'))
$sourceCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') { throw 'Physical Windows x64 is required.' }

$computer = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$processor = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuId = [Runtime.Intrinsics.X86.X86Base]::CpuId(1, 0)
$cpuFeatures = [ordered]@{
    AVX2 = [Runtime.Intrinsics.X86.Avx2]::IsSupported
    FMA = [Runtime.Intrinsics.X86.Fma]::IsSupported
    F16C = [Runtime.Intrinsics.X86.X86Base]::IsSupported -and (($cpuId.Ecx -band (1 -shl 29)) -ne 0)
    'SSE4.2' = [Runtime.Intrinsics.X86.Sse42]::IsSupported
    OS_AVX_STATE = [Runtime.Intrinsics.X86.Avx]::IsSupported
}
if ($cpuFeatures.Values -contains $false) { throw 'Required AVX2/FMA/F16C/SSE4.2 or OS AVX state is unavailable.' }
$virtualMarkers = 'Virtual|VMware|VirtualBox|KVM|QEMU|Hyper-V|Parallels'
if ($computer.Manufacturer -match $virtualMarkers -or $computer.Model -match $virtualMarkers) { throw 'Virtual hardware cannot produce physical release evidence.' }
$expectedPrefix = if ($Target -eq 'windows10') { '10.0.19045.' } else { '10.0.26200.' }
$versionKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$observedBuild = "10.0.$($versionKey.CurrentBuildNumber).$($versionKey.UBR)"
if (-not $observedBuild.StartsWith($expectedPrefix, [StringComparison]::Ordinal)) { throw "Wrong OS build for $Target`: $observedBuild" }
$expectedCaption = if ($Target -eq 'windows10') { 'Windows 10' } else { 'Windows 11' }
if ($os.Caption -notmatch ([Regex]::Escape($expectedCaption) + ' (Home|Pro)(?:\s|$)')) { throw "Only $expectedCaption Home/Pro is accepted: $($os.Caption)" }
$edition = $Matches[1]
$ramGiB = [Math]::Floor($computer.TotalPhysicalMemory / 1GB)
if ($ramGiB -lt 8) { throw 'At least 8 GiB of physical RAM is required.' }
$artifactDrive = Get-PSDrive -Name ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Artifact)).TrimEnd('\').TrimEnd(':'))
if (-not $artifactDrive -or $artifactDrive.Free -lt 1GB) { throw 'At least 1 GiB of free disk beyond the measured payload is required.' }

$operator = Get-Content -LiteralPath $Checklist -Raw | ConvertFrom-Json
$requiredChecks = @('standardUserInstall','noDeveloperTools','offlineDictation','notepad','chromeInput','chromeContenteditable','abnt2AltGr','focusRace','clipboardContention','blockedInsertion','copyAgain','microphonePermission','microphoneDisconnect','missingModel','corruptModel','inferenceFailure','cancelLockSuspend','temporaryAudioCleanup','spacesNonAsciiPath','uninstall','ownedDataRemoval','unrelatedDataPreserved')
if ([string]::IsNullOrWhiteSpace([string]$operator.verifier) -or [string]::IsNullOrWhiteSpace([string]$operator.microphone)) { throw 'Checklist requires verifier and microphone observations.' }
foreach ($name in $requiredChecks) {
    $check = $operator.checks.$name
    if (-not $check -or $check.outcome -ne 'observed-pass' -or [string]::IsNullOrWhiteSpace([string]$check.observation)) { throw "Checklist is incomplete: $name" }
}
if (@($operator.cycles).Count -ne 10) { throw 'Exactly ten observed cycles are required.' }
for ($number = 1; $number -le 10; $number++) {
    $cycle = @($operator.cycles)[$number - 1]
    if ($cycle.number -ne $number -or $cycle.recordings -ne 1 -or $cycle.clipboardCommits -ne 1 -or $cycle.insertions -ne 1 -or -not $cycle.returnedIdle -or [string]::IsNullOrWhiteSpace([string]$cycle.observation)) { throw "Invalid observed cycle: $number" }
}
if ((@($operator.corpus.language) | Sort-Object) -join ',' -ne 'en,es,pt') { throw 'Observed corpus requires pt, en and es.' }
foreach ($result in $operator.corpus) {
    if ($result.utterances -lt 5 -or $result.wordErrorRate -gt 0.20 -or -not $result.networkDisconnected -or -not $result.silenceProducedNoText) { throw "Corpus threshold failed: $($result.language)" }
    if ($result.language -eq 'en') { if ($result.anglicismRetention -ne 'not-applicable') { throw 'English anglicism retention must be not-applicable.' } }
    elseif ([decimal]$result.anglicismRetention -lt 0.9) { throw "Anglicism retention failed: $($result.language)" }
    if (-not (Test-Path -LiteralPath $result.report -PathType Leaf)) { throw "Missing corpus report: $($result.language)" }
}

$artifactInfo = Get-Item -LiteralPath $Artifact
$modelInfo = Get-Item -LiteralPath $Model
$record = [ordered]@{
    schemaVersion = 1; evidenceClass = 'observed'; target = $Target
    observedAtUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'); verifier = [string]$operator.verifier
    authorizationReference = $AuthorizationReference; sourceCommit = $sourceCommit; appVersion = $Version
    host = [ordered]@{ manufacturer = $computer.Manufacturer; model = $computer.Model; cpu = $processor.Name
        cpuFeatures = $cpuFeatures; ramGiB = $ramGiB; osCaption = $os.Caption; edition = $edition
        osVersion = $observedBuild; architecture = $os.OSArchitecture }
    microphone = [string]$operator.microphone
    artifact = [ordered]@{ path = $artifactInfo.Name; byteLength = $artifactInfo.Length; sha256 = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash.ToLowerInvariant() }
    model = [ordered]@{ path = $modelInfo.Name; byteLength = $modelInfo.Length; sha256 = (Get-FileHash -LiteralPath $Model -Algorithm SHA256).Hash.ToLowerInvariant() }
    checks = $operator.checks; cycles = $operator.cycles
    corpus = @($operator.corpus | ForEach-Object { [ordered]@{ language = $_.language; utterances = $_.utterances; wordErrorRate = $_.wordErrorRate
        anglicismRetention = $_.anglicismRetention; networkDisconnected = $_.networkDisconnected; silenceProducedNoText = $_.silenceProducedNoText
        reportPath = [IO.Path]::GetFileName($_.report); reportSha256 = (Get-FileHash -LiteralPath $_.report -Algorithm SHA256).Hash.ToLowerInvariant() } })
}
$record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Output -Encoding utf8NoBOM
Write-Host "Observed physical evidence collected: $Output"
