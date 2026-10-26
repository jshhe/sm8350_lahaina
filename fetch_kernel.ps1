# Fetch OnePlus 9 Pro Linux 5.4 Kernel Sources
# Default branch is oneplus/sm8350_u_14.0.0_oneplus9 (Android 14 / Linux 5.4.254)

param (
    [string]$Branch = "oneplus/sm8350_u_14.0.0_oneplus9",
    [string]$GitPath = ""
)

if (-not $GitPath) {
    $GitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($GitCmd) {
        $GitPath = $GitCmd.Source
    } else {
        # Check GitHub Desktop internal git
        $found = Get-ChildItem -Path "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1
        if ($found) {
            $GitPath = $found.FullName
        }
    }
}

if (-not $GitPath) {
    Write-Error "Git not found. Please install Git or provide -GitPath."
    exit 1
}

Write-Host "Using Git at: $GitPath"
Write-Host "Cloning branch: $Branch"

$workDir = $PSScriptRoot

# 1. Clone kernel source
$kernelDir = Join-Path $workDir "kernel\msm-5.4"
if (-not (Test-Path $kernelDir)) {
    Write-Host "Cloning OnePlusOSS/android_kernel_oneplus_sm8350 into $kernelDir..."
    & $GitPath clone --depth=1 -b $Branch https://github.com/OnePlusOSS/android_kernel_oneplus_sm8350.git $kernelDir
} else {
    Write-Host "Kernel directory $kernelDir already exists. Skipping."
}

# 2. Clone modules & devicetree (for Android 12.1 ~ 14)
$modulesDir = Join-Path $workDir "modules_and_devicetree"
if (-not (Test-Path $modulesDir)) {
    Write-Host "Cloning OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8350 into $modulesDir..."
    & $GitPath clone --depth=1 -b $Branch https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8350.git $modulesDir
} else {
    Write-Host "Modules directory $modulesDir already exists. Skipping."
}

Write-Host "Done! All source components fetched into $workDir"
