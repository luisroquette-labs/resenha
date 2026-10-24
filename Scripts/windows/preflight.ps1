[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path $scriptPath -Parent) '../..'))
$windowsRoot = Join-Path $repositoryRoot 'Windows'
$mutex = $null
$hasMutex = $false

function Require-Command([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) { throw "Required tool is missing: $Name" }
    return $command
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Normalize-Words([string]$Text) {
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
    return @(($normalized -replace '[^\p{L}\p{M}\p{Nd}]+', ' ').Trim() -split '\s+' | Where-Object { $_ })
}

function Get-EditDistance([string[]]$Expected, [string[]]$Actual) {
    $matrix = New-Object 'int[,]' ($Expected.Count + 1), ($Actual.Count + 1)
    for ($i = 0; $i -le $Expected.Count; $i++) { $matrix[$i, 0] = $i }
    for ($j = 0; $j -le $Actual.Count; $j++) { $matrix[0, $j] = $j }
    for ($i = 1; $i -le $Expected.Count; $i++) {
        for ($j = 1; $j -le $Actual.Count; $j++) {
            $cost = [int]($Expected[$i - 1] -cne $Actual[$j - 1])
            $matrix[$i, $j] = [Math]::Min($matrix[$i - 1, $j] + 1,
                [Math]::Min($matrix[$i, $j - 1] + 1, $matrix[$i - 1, $j - 1] + $cost))
        }
    }
    return $matrix[$Expected.Count, $Actual.Count]
}

try {
    if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
        throw 'Windows x64 is required; cross-compilation is not native validation.'
    }
    $mutex = [Threading.Mutex]::new($false, 'Local\Resenha-Windows-Preflight')
    $hasMutex = $mutex.WaitOne([TimeSpan]::FromMinutes(10))
    if (-not $hasMutex) { throw 'Another Resenha Windows preflight owns the host mutex.' }

    Push-Location $windowsRoot
    try {
        $lock = Get-Content -LiteralPath 'toolchain-lock.json' -Raw | ConvertFrom-Json
        if (-not $lock.approvedHostInventory -or $lock.status -ne 'approved-windows-host') {
            throw 'toolchain-lock.json has no approved Windows host inventory.'
        }
        foreach ($field in $lock.requiredInventoryFields) {
            if (-not $lock.approvedHostInventory.PSObject.Properties[$field] -or
                [string]::IsNullOrWhiteSpace([string]$lock.approvedHostInventory.$field)) {
                throw "Approved host inventory is incomplete: $field"
            }
        }

        $dotnet = Require-Command 'dotnet'
        $cmake = Require-Command 'cmake'
        Require-Command 'git' | Out-Null
        Require-Command 'cl' | Out-Null
        Require-Command 'link' | Out-Null
        Require-Command 'iscc' | Out-Null
        if ((& $dotnet --version).Trim() -ne $lock.requirements.dotnetSdk) {
            throw "Wrong .NET SDK; expected $($lock.requirements.dotnetSdk)."
        }

        & $dotnet restore 'Resenha.Windows.sln' --locked-mode
        if ($LASTEXITCODE) { throw 'Locked restore failed.' }
        & $dotnet format 'Resenha.Windows.sln' --verify-no-changes --no-restore
        if ($LASTEXITCODE) { throw 'Format verification failed.' }
        & $dotnet build 'Resenha.Windows.sln' --configuration Release --no-restore --no-incremental -warnaserror
        if ($LASTEXITCODE) { throw 'Release build failed.' }
        & $dotnet test 'Resenha.Core.Tests/Resenha.Core.Tests.csproj' --configuration Release --no-build --no-restore
        if ($LASTEXITCODE) { throw 'Core tests failed.' }
        & $dotnet test 'Resenha.Platform.Tests/Resenha.Platform.Tests.csproj' --configuration Release --no-build --no-restore
        if ($LASTEXITCODE) { throw 'Platform tests failed.' }

        Push-Location 'native'
        try {
            & $cmake --preset windows-x64-cpu
            if ($LASTEXITCODE) { throw 'Pinned whisper.cpp configuration failed.' }
            & $cmake --build --preset windows-x64-cpu
            if ($LASTEXITCODE) { throw 'Pinned whisper.cpp build failed.' }
        }
        finally {
            Pop-Location
        }
        $cli = Join-Path $windowsRoot 'native/build/windows-x64-cpu/bin/Release/whisper-cli.exe'
        if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) { throw 'whisper-cli.exe was not produced.' }

        $modelManifest = Get-Content -LiteralPath 'model-manifest.json' -Raw | ConvertFrom-Json
        $model = Join-Path $env:LOCALAPPDATA "Resenha/models/$($modelManifest.fileName)"
        if (-not (Test-Path -LiteralPath $model -PathType Leaf) -or
            (Get-Item -LiteralPath $model).Length -ne $modelManifest.byteLength -or
            (Get-Sha256 $model) -ne $modelManifest.sha256) {
            throw 'The exact verified local model is missing.'
        }
        $corpus = Get-Content -LiteralPath 'Fixtures/speech-corpus.json' -Raw | ConvertFrom-Json
        if ($corpus.status -ne 'ready' -or -not $corpus.measurement) {
            throw 'Speech corpus is not rights-cleared and measurement-ready.'
        }
        $languageResults = @{}
        foreach ($utterance in $corpus.utterances) {
            $audio = Join-Path $windowsRoot "Fixtures/$($utterance.file)"
            if (-not $utterance.rights -or -not $utterance.sha256 -or
                -not (Test-Path -LiteralPath $audio -PathType Leaf) -or
                (Get-Sha256 $audio) -ne $utterance.sha256) {
                throw "Corpus evidence is incomplete: $($utterance.id)"
            }
            $outputRoot = Join-Path $env:TEMP "resenha-corpus-$($utterance.id)-$([Guid]::NewGuid().ToString('N'))"
            & $cli -m $model -f $audio -l $utterance.language -otxt -of $outputRoot --no-timestamps --temperature 0 --beam-size 5 --no-fallback
            if ($LASTEXITCODE -or -not (Test-Path -LiteralPath "$outputRoot.txt")) { throw "Inference failed: $($utterance.id)" }
            $actual = Get-Content -LiteralPath "$outputRoot.txt" -Raw
            Remove-Item -LiteralPath "$outputRoot.txt" -Force
            $expectedWords = Normalize-Words $utterance.reference
            $actualWords = Normalize-Words $actual
            if (-not $languageResults[$utterance.language]) { $languageResults[$utterance.language] = [Collections.Generic.List[double]]::new() }
            $denominator = [Math]::Max(1, $expectedWords.Count)
            $languageResults[$utterance.language].Add((Get-EditDistance $expectedWords $actualWords) / $denominator)
            foreach ($term in $utterance.anglicisms) {
                if ($actual.Normalize([Text.NormalizationForm]::FormC).IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                    throw "Anglicism was not retained: $($utterance.id) / $term"
                }
            }
        }
        foreach ($language in @('pt', 'en', 'es')) {
            $average = ($languageResults[$language] | Measure-Object -Average).Average
            if ($average -gt $corpus.requirements.maximumWerPerLanguage) { throw "WER failed for $language`: $average" }
        }
        Write-Host 'Resenha Windows native preflight: PASS'
    }
    finally { Pop-Location }
}
finally {
    if ($hasMutex) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
