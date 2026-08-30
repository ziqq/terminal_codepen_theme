[CmdletBinding()]
param(
    [ValidateSet('default', 'cool')]
    [string]$Variant = 'default',

    [switch]$NoGitHelper,

    [switch]$SkipPackageInstall,

    [string]$Msys2Root
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$bridgeStart = '# >>> terminal_codepen_theme Windows bridge >>>'
$bridgeEnd = '# <<< terminal_codepen_theme Windows bridge <<<'

function Write-Info {
    param([string]$Message)

    Write-Host "terminal_codepen_theme: $Message"
}

function Find-Msys2Root {
    param([string]$RequestedRoot)

    $candidates = @()
    if ($RequestedRoot) {
        $candidates += $RequestedRoot
    }
    if ($env:MSYS2_ROOT) {
        $candidates += $env:MSYS2_ROOT
    }
    $candidates += @(
        'C:\msys64',
        (Join-Path $env:LOCALAPPDATA 'Programs\MSYS2'),
        (Join-Path $env:LOCALAPPDATA 'MSYS2')
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'usr\bin\bash.exe'))) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Install-Msys2 {
    if ($SkipPackageInstall) {
        throw 'MSYS2 is not installed. Rerun without -SkipPackageInstall, or pass -Msys2Root.'
    }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'MSYS2 is required. Install it from https://www.msys2.org/ or install winget, then rerun.'
    }

    Write-Info 'installing MSYS2 with winget'
    & winget.exe install --id MSYS2.MSYS2 --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install MSYS2 (exit code $LASTEXITCODE)"
    }
}

function Install-Msys2Packages {
    param([string]$Root)

    $zshPath = Join-Path $Root 'usr\bin\zsh.exe'
    $gitPath = Join-Path $Root 'usr\bin\git.exe'
    $curlPath = Join-Path $Root 'usr\bin\curl.exe'
    if ((Test-Path -LiteralPath $zshPath) -and
        (Test-Path -LiteralPath $gitPath) -and
        (Test-Path -LiteralPath $curlPath)) {
        return
    }
    if ($SkipPackageInstall) {
        throw 'MSYS2 is missing one or more required packages: zsh, git, curl.'
    }

    $pacmanPath = Join-Path $Root 'usr\bin\pacman.exe'
    if (-not (Test-Path -LiteralPath $pacmanPath)) {
        throw "pacman was not found at $pacmanPath"
    }

    Write-Info 'updating MSYS2 packages'
    & $pacmanPath -Syu --noconfirm
    if ($LASTEXITCODE -ne 0) {
        throw "pacman update failed (exit code $LASTEXITCODE)"
    }

    Write-Info 'installing zsh, git, and curl in MSYS2'
    & $pacmanPath -S --needed --noconfirm zsh git curl
    if ($LASTEXITCODE -ne 0) {
        throw "pacman package installation failed (exit code $LASTEXITCODE)"
    }
}

function Convert-ToMsysPath {
    param(
        [string]$Cygpath,
        [string]$WindowsPath
    )

    $converted = & $Cygpath -u $WindowsPath
    if ($LASTEXITCODE -ne 0 -or -not $converted) {
        throw "cannot convert path for MSYS2: $WindowsPath"
    }
    return ($converted | Select-Object -First 1).Trim()
}

function Convert-ToZshSingleQuoted {
    param([string]$Value)

    return $Value.Replace("'", "'\''")
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Update-Msys2Bridge {
    param(
        [string]$BridgePath,
        [string]$TargetHome
    )

    $bridgeDirectory = Split-Path -Parent $BridgePath
    if (-not (Test-Path -LiteralPath $bridgeDirectory)) {
        New-Item -ItemType Directory -Path $bridgeDirectory -Force | Out-Null
    }

    $quotedHome = Convert-ToZshSingleQuoted -Value $TargetHome
$block = @"
$bridgeStart
export PATH="/usr/bin:/bin:`$PATH"
export ZDOTDIR='$quotedHome'
source "`$ZDOTDIR/.zshrc"
$bridgeEnd
"@

    if (Test-Path -LiteralPath $BridgePath) {
        $backupPath = "$BridgePath.pre-terminal-codepen-theme"
        if (-not (Test-Path -LiteralPath $backupPath)) {
            Copy-Item -LiteralPath $BridgePath -Destination $backupPath
        }
        $content = Get-Content -LiteralPath $BridgePath -Raw
        $pattern = '(?ms)^' + [regex]::Escape($bridgeStart) + '.*?^' + [regex]::Escape($bridgeEnd) + '\r?\n?'
        $content = [regex]::Replace($content, $pattern, '')
        $content = $content.TrimEnd("`r", "`n")
        if ($content) {
            $content += "`r`n`r`n"
        }
        $content += $block + "`r`n"
        Write-Utf8NoBom -Path $BridgePath -Content $content
    } else {
        Write-Utf8NoBom -Path $BridgePath -Content ($block + "`r`n")
    }

    Write-Info "updated MSYS2 bridge at $BridgePath"
}

$resolvedMsys2Root = Find-Msys2Root -RequestedRoot $Msys2Root
if (-not $resolvedMsys2Root) {
    Install-Msys2
    $resolvedMsys2Root = Find-Msys2Root -RequestedRoot $Msys2Root
}
if (-not $resolvedMsys2Root) {
    throw 'MSYS2 was installed, but its installation directory could not be located. Pass -Msys2Root.'
}

Install-Msys2Packages -Root $resolvedMsys2Root

$bashPath = Join-Path $resolvedMsys2Root 'usr\bin\bash.exe'
$zshPath = Join-Path $resolvedMsys2Root 'usr\bin\zsh.exe'
$cygpath = Join-Path $resolvedMsys2Root 'usr\bin\cygpath.exe'
$scriptPath = Join-Path $PSScriptRoot 'install.sh'
$scriptMsysPath = Convert-ToMsysPath -Cygpath $cygpath -WindowsPath $scriptPath
$windowsHomeMsysPath = Convert-ToMsysPath -Cygpath $cygpath -WindowsPath $env:USERPROFILE

$previousHome = $env:HOME
$previousZdotdir = $env:ZDOTDIR
$previousPath = $env:PATH
try {
    $env:PATH = (Join-Path $resolvedMsys2Root 'usr\bin') + ';' +
        (Join-Path $resolvedMsys2Root 'mingw64\bin') + ';' + $previousPath
    $msysHomeMsysPath = (& $bashPath --noprofile --norc -lc 'printf %s "$HOME"').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $msysHomeMsysPath) {
        throw 'could not determine the MSYS2 home directory'
    }

    $env:HOME = $windowsHomeMsysPath
    $env:ZDOTDIR = $windowsHomeMsysPath

    $installerArguments = @($scriptMsysPath, '--variant', $Variant, '--skip-package-install')
    if ($NoGitHelper) {
        $installerArguments += '--no-git-helper'
    }

    & $bashPath @installerArguments
    if ($LASTEXITCODE -ne 0) {
        throw "install.sh failed (exit code $LASTEXITCODE)"
    }

    if ($msysHomeMsysPath -ne $windowsHomeMsysPath) {
        $msysHomeWindowsPath = (& $cygpath -w $msysHomeMsysPath).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $msysHomeWindowsPath) {
            throw 'could not convert the MSYS2 home directory to a Windows path'
        }
        Update-Msys2Bridge -BridgePath (Join-Path $msysHomeWindowsPath '.zshrc') -TargetHome $windowsHomeMsysPath
    }

    & $bashPath --noprofile --norc -c 'export PATH=/usr/bin:/bin:$PATH; exec zsh -ic ''print -r -- "terminal_codepen_theme: active theme=$ZSH_THEME"'''
    if ($LASTEXITCODE -ne 0) {
        throw "Zsh verification failed (exit code $LASTEXITCODE)"
    }
} finally {
    $env:HOME = $previousHome
    $env:ZDOTDIR = $previousZdotdir
    $env:PATH = $previousPath
}

Write-Info "installed variant '$Variant' for the current Windows user"
Write-Info "launch Zsh with: & '$zshPath' -l"
