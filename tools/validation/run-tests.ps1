param([string]$Flutter = "C:\dev\flutter\bin\flutter.bat")
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$Results = Join-Path $Root 'test-results'
New-Item -ItemType Directory -Force -Path $Results | Out-Null
function Run-Checked([string]$Name, [string]$Command, [string[]]$Arguments) {
    # Windows PowerShell 5.1 representa stderr nativo como ErrorRecord.
    # Uma mensagem em stderr não significa que o processo falhou.
    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Command @Arguments 2>&1 | Tee-Object -FilePath (Join-Path $Results "$Name.log")
        $CommandExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousPreference
    }
    if ($CommandExitCode -ne 0) {
        throw "$Name falhou (código $CommandExitCode): veja test-results/$Name.log"
    }
}
Push-Location $Root
try {
    if (!(Test-Path $Flutter)) { throw "Flutter não encontrado: $Flutter" }
    Run-Checked 'api-contracts' 'node' @('tools/validation/contracts.test.mjs')
    Run-Checked 'npm-install' 'npm.cmd' @('ci', '--prefix', 'tools/database')
    Run-Checked 'database' 'npm.cmd' @('test', '--prefix', 'tools/database')
    Push-Location 'flutter_project'
    try {
        Run-Checked 'dependencies' $Flutter @('pub', 'get')
        $Dart = Join-Path (Split-Path $Flutter) 'dart.bat'
        Run-Checked 'format' $Dart @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test')
        Run-Checked 'analysis' $Flutter @('analyze', '--no-fatal-infos')
        Run-Checked 'flutter-tests' $Flutter @('test', '--coverage', '--reporter', 'expanded')
        Copy-Item 'coverage/lcov.info' (Join-Path $Results 'lcov.info')
        Run-Checked 'android-build' $Flutter @('build', 'apk', '--debug')
    } finally { Pop-Location }
    Write-Host 'Validação concluída. Logs e cobertura: test-results'
} finally { Pop-Location }
