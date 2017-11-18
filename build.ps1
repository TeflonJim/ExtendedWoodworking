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

        $stopWatch = New-Object System.Diagnostics.StopWatch
        $stopWatch.Start()

        try {
            . "$psscriptroot\build_$_.ps1"
        } catch {
            $result = 'Fail'
            $messageColor = 'Red'

            throw
        } finally {
            $stopWatch.Stop()

            Write-Host -ForegroundColor $messageColor -Object ('    {0}{1}{2}' -f
                $step.PadRight(40, ' '),
                $result.PadRight(10, ' '),
                $stopWatch.Elapsed
            )
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
# WoodLog stats table
#

# These values are only used if the build profile implements the WoodLog

$colours = @{
    Acacia        = '(219, 184, 144)'
    Birch         = '(235,228,216)'
    Camellia      = '(201, 160, 130)'
    Cecropia      = '(126,74,63)'
    CherryBlossom = '(165, 82, 40)'
    Cypress       = '(239, 217, 184)'
    Drago         = '(171, 159, 142)'
    JapaneseMaple = '(252, 170, 124)'
    Maple         = '(236, 201, 163)'
    Oak           = '(185,142,96)'
    Palm          = '(224, 150, 87)'
    Pine          = '(198,146,68)'
    Poplar        = '(184,156,108)'
    RedMaple      = '(222, 197, 167)'
    Teak          = '(154,102,59)'
    Willow        = '(221, 186, 141)'
    Red           = '(200,0,0)'
    Green         = '(0,200,0)'
    Blue          = '(0,0,200)'
    Yellow        = '(200,200,0)'
    White         = '(255,255,255)'
    Black         = '(50,50,50)'
}

# Stats need fixing up.

$woodStats = @{
    Acacia        = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Birch         = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.3 }
    Camellia      = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 2;   WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Cecropia      = [PSCustomObject]@{ MaxHitPoints = 0.5;  StructuralBeauty = 1;   WorkToMake = 0.5; DoorOpenSpeed = 1.2 }
    CherryBlossom = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 1;   WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Cypress       = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 2.5; WorkToMake = 0.7; DoorOpenSpeed = 1.1 }
    Drago         = [PSCustomObject]@{ MaxHitPoints = 0.2;  StructuralBeauty = 0.5; WorkToMake = 0.9; DoorOpenSpeed = 1.6 }
    JapaneseMaple = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpeed = 1.2 }
    Maple         = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpeed = 1.2 }
    Oak           = [PSCustomObject]@{ MaxHitPoints = 0.75; StructuralBeauty = 2.5; WorkToMake = 0.9; DoorOpenSpeed = 1.1 }
    Palm          = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Pine          = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Poplar        = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    RedMaple      = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpped = 1.2 }
    Teak          = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 2.5; WorkToMake = 1.1; DoorOpenSpeed = 1.2 }
    Willow        = [PSCustomObject]@{ MaxHitPoints = 0.2;  StructuralBeauty = 0.5; WorkToMake = 0.5; DoorOpenSpeed = 1.6 }
}

#
# Build init
#

Remove-Item build -Recurse

#
# Default
#

Write-Host
Write-Host "Building Extended Woodworking" -ForegroundColor White

$build = "$psscriptroot\build\ExtendedWoodworking"

$null = New-Item $build -ItemType Directory
Copy-Item "$psscriptroot\source\*" $build -Recurse

Set-Content $build\About\PublishedFileId.txt -Value '836912371'

$natural = 'Birch',
           'Cecropia',
           'Cypress',
           'Drago',
           'Maple',
           'Oak',
           'Palm',
           'Poplar',
           'Pine',
           'Teak',
           'Willow'

$painted = 'Red',
           'Green',
           'Blue',
           'Yellow',
           'White',
           'Black'

$allWood = @('WoodLog') + @($natural + $painted | ForEach-Object { 'WoodLog_{0}' -f $_ })

try {
    'RecipeDefs', 'TerrainDefs', 'ThingDefs_Buildings', 'ThingDefs_Items', 'ThingDefs_Plants' | Invoke-BuildStep
} catch {
    throw
}

#
# Vegetable Garden
#

Write-Host
Write-Host "Building Extended Woodworking - Vegetable Garden add-on" -ForegroundColor White

$build = "$psscriptroot\build\ExtendedWoodworking_VGAddOn"

$null = New-Item "$build\Defs", "$build\Textures" -ItemType Directory -Force
Copy-Item "$psscriptroot\source\About*" $build -Recurse
Copy-Item "$psscriptroot\source\Defs\ThingDefs_Items*" "$build\Defs" -Exclude 'EW-PaintedWood.xml' -Recurse
Copy-Item "$psscriptroot\source\Defs\ThingDefs_Plants*" "$build\Defs" -Recurse
Copy-Item "$psscriptroot\source\Textures\Logs*" "$build\Textures" -Recurse

Set-Content $build\About\PublishedFileId.txt -Value '1204886236'

$XDocument = [System.Xml.Linq.XDocument]::Load("$build\About\About.xml")
$XDocument.Element('ModMetaData').Element('name').SetValue('Extended Woodworking - Vegetable Garden add-on')
$XDocument.Save("$build\About\About.xml")

$natural = 'Acacia',
           'Camellia',
           'CherryBlossom',
           'JapaneseMaple',
           'RedMaple'
$painted = $null

try {
    'ThingDefs_Items', 'ThingDefs_Plants_VegetableGarden' |
        Invoke-BuildStep
} catch {
    throw
}

#
# Release packaging
#

Write-Host
Write-Host "Creating packages"

Get-ChildItem "$psscriptroot\build" -Directory | ForEach-Object {
    Write-Host "    $($_.Name)" -ForegroundColor Cyan
    
    Compress-Archive -Path $_.FullName -DestinationPath "$psscriptroot\build\$($_.Name).zip"
}

#
# Push to Mods
#

$path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 294100' -Name 'InstallLocation').InstallLocation
Get-ChildItem "$psscriptroot\build" -Directory | ForEach-Object {
    Copy-Item $_.FullName "$path\Mods" -Recurse -Force
}