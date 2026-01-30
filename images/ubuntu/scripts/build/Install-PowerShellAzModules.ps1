################################################################################
##  File:  Install-PowerShellAzModules.ps1
##  Desc:  Install Az modules for PowerShell (s390x Robust Version)
################################################################################

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Import-Module "$env:HELPER_SCRIPTS/../tests/Helpers.psm1"

# Trust PSGallery
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Get modules from toolset
$modules = (Get-ToolsetContent).azureModules
$installPSModulePath = "/usr/share"

foreach ($module in $modules) {
    $moduleName = $module.name

    Write-Host "Installing ${moduleName} to the ${installPSModulePath} path..."
    foreach ($version in $module.versions) {
        $modulePath = Join-Path -Path $installPSModulePath -ChildPath "${moduleName}_${version}"
        Write-Host " - $version [$modulePath]"
        
        # 1. Download Module
        # We use Save-Module which might create subdirectories (e.g. ./Az/12.5.0/Az.psd1)
        Save-Module -Path $modulePath -Name $moduleName -RequiredVersion $version -Force -Repository PSGallery -ErrorAction Stop

        # 2. Validation (Recursive)
        # Instead of guessing the depth, we look for ANY .psd1 file inside the target folder recursively.
        $manifests = Get-ChildItem -Path $modulePath -Filter "*.psd1" -Recurse -ErrorAction SilentlyContinue

        if ($manifests.Count -gt 0) {
            Write-Host "   [Verified] Found manifest: $($manifests[0].FullName)" -ForegroundColor Green
        } else {
            # --- DEBUG INFO START ---
            Write-Warning "   [Debug] Download seemed to finish, but validation failed."
            Write-Warning "   [Debug] Listing contents of $modulePath to see what happened:"
            Get-ChildItem -Path $modulePath -Recurse | Select-Object FullName | Format-Table -AutoSize | Out-String | Write-Warning
            # --- DEBUG INFO END ---

            Throw "   [Error] Module downloaded but no manifest (*.psd1) found anywhere in $modulePath"
        }
    }
}

# Skipped Pester tests to avoid s390x .NET runtime limitations
# Invoke-PesterTests -TestFile "PowerShellModules" -TestName "AzureModules"
