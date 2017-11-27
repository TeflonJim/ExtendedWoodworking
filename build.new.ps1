#Requires -Module Indented.RimWorld

param(
    [ValidateSet('Major', 'Minor', 'Build')]
    [String]$ReleaseType = 'Build'
)

function Invoke-BuildStep {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $step
    )

    process {
        $result = 'Success'
        $messageColor = 'Cyan'

        Write-Host -ForegroundColor $messageColor -Object ('    {0}' -f $step.PadRight(40, ' ')) -NoNewline

        $stopWatch = New-Object System.Diagnostics.StopWatch
        $stopWatch.Start()

        try {
            . "$psscriptroot\build_$_.ps1"
            $result = 'Success'
            Write-Host -ForegroundColor $messageColor -Object ('    {0}' -f $result.PadRight(10, ' ')) -NoNewline
        } catch {
            $result = 'Fail'
            Write-Host -ForegroundColor 'Red' -Object ('    {0}' -f $result.PadRight(10, ' ')) -NoNewline
            
            throw
        } finally {
            $stopWatch.Stop()
                
            Write-Host -ForegroundColor $messageColor -Object $stopWatch.Elapsed
        }
    }
}

Set-Variable ErrorActionPreference -Value Stop -Scope Script

#
# Versioning
#

Add-Type -AssemblyName System.Xml.Linq

[Version]$version = Get-Content "$psscriptroot\source\About\version.txt" -Raw
$version = switch ($ReleaseType) {
    'Major' { New-Object Version(($version.Major + 1), 0, 0) }
    'Minor' { New-Object Version($version.Major, ($version.Minor + 1), 0) }
    'Build' { New-Object Version($version.Major, $version.Minor, ($version.Build + 1)) }
}
Set-Content "$psscriptroot\source\About\version.txt" -Value $version.ToString()

Write-Host "Starting build for $version" -ForegroundColor Yellow

#
# Supported mods (costList rewriting)
#

$supportedMods = @(
    'Core'
    '[RF] Basic Bridges - Fishing Add-On'
    '[RF] Fertile Fields'
    '[T] ExpandedCloth'
    '[T] MoreFloors'
    'A Dog Said...'
    'Area Rugs'
    'Misc. Training'
    'VGP Xtra Trees and Flowers'
)

#
# WoodLog stats table
#

# These values are only used if the build profile implements the WoodLog

$painted = [Ordered]@{
    Red           = '(200,0,0)'
    Green         = '(0,200,0)'
    Blue          = '(0,0,200)'
    Yellow        = '(200,200,0)'
    White         = '(255,255,255)'
    Black         = '(50,50,50)'
}

# Stats need fixing up.

$woodStats = [Ordered]@{
    Acacia        = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2; Colour = '(219, 184, 144)'; Mod = 'VGP Xtra Trees and Flowers' }
    Birch         = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.3; Colour = '(235,228,216)' }
    Camellia      = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 2;   WorkToMake = 0.7; DoorOpenSpeed = 1.2; Colour = '(201, 160, 130)'; Mod = 'VGP Xtra Trees and Flowers' }
    Cecropia      = [PSCustomObject]@{ MaxHitPoints = 0.5;  StructuralBeauty = 1;   WorkToMake = 0.5; DoorOpenSpeed = 1.2; Colour = '(126,74,63)' }
    CherryBlossom = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 1;   WorkToMake = 0.7; DoorOpenSpeed = 1.2; Colour = '(165, 82, 40)';   Mod = 'VGP Xtra Trees and Flowers' }
    Cypress       = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 2.5; WorkToMake = 0.7; DoorOpenSpeed = 1.1; Colour = '(239, 217, 184)' }
    Drago         = [PSCustomObject]@{ MaxHitPoints = 0.2;  StructuralBeauty = 0.5; WorkToMake = 0.9; DoorOpenSpeed = 1.6; Colour = '(171, 159, 142)' }
    JapaneseMaple = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpeed = 1.2; Colour = '(252, 170, 124)'; Mod = 'VGP Xtra Trees and Flowers' }
    Maple         = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpeed = 1.2; Colour = '(236, 201, 163)' }
    Oak           = [PSCustomObject]@{ MaxHitPoints = 0.75; StructuralBeauty = 2.5; WorkToMake = 0.9; DoorOpenSpeed = 1.0; Colour = '(185,142,96)' }
    Palm          = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2; Colour = '(224, 150, 87)' }
    Pine          = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.0; Colour = '(198,146,68)' }
    Poplar        = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2; Colour = '(184,156,108)' }
    RedMaple      = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpeed = 1.2; Colour = '(222, 197, 167)'; Mod = 'VGP Xtra Trees and Flowers' }
    Teak          = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 2.5; WorkToMake = 1.1; DoorOpenSpeed = 1.2; Colour = '(154,102,59)' }
    Willow        = [PSCustomObject]@{ MaxHitPoints = 0.2;  StructuralBeauty = 0.5; WorkToMake = 0.5; DoorOpenSpeed = 1.6; Colour = '(221, 186, 141)' }
}

#
# Build init
#

$build = "$psscriptroot\generated\ExtendedWoodworking"

if (Test-Path $build) {
    Remove-Item $build -Recurse
}
if (Test-Path "$psscriptroot\build") {
    Remove-Item "$psscriptroot\build\*" -Recurse
}
if (-not (Test-Path "$psscriptroot\build")) {
    $null = New-Item "$psscriptroot\build" -ItemType Directory
}

#
# Default
#

Write-Host
Write-Host "Building Extended Woodworking" -ForegroundColor White

$null = New-Item $build -ItemType Directory
Copy-Item "$psscriptroot\source\*" $build -Recurse

Set-Content $build\About\PublishedFileId.txt -Value '836912371'

[System.Collections.Generic.Hashset[String]]$allWood = 'WoodLog'
foreach ($name in $woodStats.Keys) {
    $null = $allWood.Add($name)
}
foreach ($name in $painted.Keys) {
    $null = $allWood.Add($name)
}

try {
    'RecipeDefs', 'TerrainDefs', 'ThingDefs_Buildings', 'ThingDefs_Items', 'Patches' | Invoke-BuildStep
} catch {
    throw
}

#
# Release packaging
#

Write-Host
Write-Host "Creating packages"

Get-ChildItem "$psscriptroot\generated" -Directory | ForEach-Object {
    Write-Host "    $($_.Name)" -ForegroundColor Cyan
    
    Compress-Archive -Path $_.FullName -DestinationPath "$psscriptroot\build\$($_.Name).zip"
}

# Clean up

Remove-Item "$build\Patches\EW-*%*"

#
# Push to Mods
#

$path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 294100' -Name 'InstallLocation').InstallLocation
Get-ChildItem "$psscriptroot\generated" -Directory | ForEach-Object {
    if (Test-Path "$path\Mods\$($_.Name)") {
        Remove-Item "$path\Mods\$($_.Name)" -Recurse
    }

    Copy-Item $_.FullName "$path\Mods" -Recurse -Force
}