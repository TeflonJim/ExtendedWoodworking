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
    Oak           = '(185,142,96)'
    Poplar        = '(184,156,108)'
    Pine          = '(198,146,68)'
    Birch         = '(235,228,216)'
    Cecropia      = '(126,74,63)'
    Teak          = '(154,102,59)'
    WeepingWillow = '(221, 186, 141)'
    JapaneseMaple = '(252, 170, 124)'
    CherryBlossom = '(165, 82, 40)'
    Camellia      = '(201, 160, 130)'
    Acacia        = '(219, 184, 144)'
    Palm          = '(224, 150, 87)'
    RedMaple      = '(222, 197, 167)'
    Red           = '(200,0,0)'
    Green         = '(0,200,0)'
    Blue          = '(0,0,200)'
    Yellow        = '(200,200,0)'
    White         = '(255,255,255)'
    Black         = '(50,50,50)'
}

# Stats need fixing up.

$woodStats = @{
    Oak           = [PSCustomObject]@{ MaxHitPoints = 0.75; StructuralBeauty = 2.5; WorkToMake = 0.9; DoorOpenSpeed = 1.1 }
    Poplar        = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Pine          = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Birch         = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.3 }
    Cecropia      = [PSCustomObject]@{ MaxHitPoints = 0.5;  StructuralBeauty = 1;   WorkToMake = 0.5; DoorOpenSpeed = 1.2 }
    Teak          = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 2.5; WorkToMake = 1.1; DoorOpenSpeed = 1.2 }
    WeepingWillow = [PSCustomObject]@{ MaxHitPoints = 0.2;  StructuralBeauty = 0.5; WorkToMake = 0.5; DoorOpenSpeed = 1.6 }
    JapaneseMaple = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpeed = 1.2 }
    CherryBlossom = [PSCustomObject]@{ MaxHitPoints = 0.7;  StructuralBeauty = 1;   WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Camellia      = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 2;   WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Acacia        = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    Palm          = [PSCustomObject]@{ MaxHitPoints = 0.6;  StructuralBeauty = 1.5; WorkToMake = 0.7; DoorOpenSpeed = 1.2 }
    RedMaple      = [PSCustomObject]@{ MaxHitPoints = 0.3;  StructuralBeauty = 1.5; WorkToMake = 0.5; DoorOpenSpped = 1.2 }
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

$natural = 'Oak',
           'Poplar',
           'Pine',
           'Birch',
           'Cecropia',
           'Teak'

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
Write-Host "Building Extended Woodworking for Vegetable Garden" -ForegroundColor White

#$build = "$psscriptroot\build\ExtendedWoodworking_VG"
#
#$null = New-Item $build -ItemType Directory
#Copy-Item "$psscriptroot\source\*" $build -Recurse
#
#Set-Content $build\About\PublishedFileId.txt -Value '836915139'
#
#$XDocument = [System.Xml.Linq.XDocument]::Load("$build\About\About.xml")
#$XDocument.Element('ModMetaData').Element('name').SetValue('Extended Woodworking for Vegetable Garden')
#$XDocument.Save("$build\About\About.xml")
#
#$natural += 'WeepingWillow',
#            'JapaneseMaple',
#            'CherryBlossom',
#            'Camellia',
#            'Acacia',
#            'Palm',
#            'RedMaple'
#
#$allWood = @('WoodLog') + @($natural + $painted | ForEach-Object { 'WoodLog_{0}' -f $_ })
#
#try {
#    'RecipeDefs', 'TerrainDefs', 'ThingDefs_Buildings', 'ThingDefs_Items', 'ThingDefs_Plants_VegetableGarden' |
#        Invoke-BuildStep
#} catch {
#    throw
#}

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