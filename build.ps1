param(
    [ValidateSet('Major', 'Minor', 'Build')]
    [String]$ReleaseType = 'Build'
)

#
# Version numbering
#

Add-Type -AssemblyName System.Xml.Linq

[Version]$version = Get-Content "$psscriptroot\source\About\version.txt" -Raw
$version = switch ($ReleaseType) {
    'Major' { New-Object Version(($version.Major + 1), 0, 0) }
    'Minor' { New-Object Version($version.Major, ($version.Minor + 1), 0) }
    'Build' { New-Object Version($version.Major, $version.Minor, ($version.Build + 1)) }
}
Set-Content "$psscriptroot\source\About\version.txt" -Value $version.ToString()

Remove-Item Build -Recurse
$null = New-Item Build -ItemType Directory
Copy-Item source\* build -Recurse

$allWood = 'WoodLog',
           'WoodLog_Oak',
           'WoodLog_Poplar',
           'WoodLog_Pine',
           'WoodLog_Birch',
           'WoodLog_Teak',
           'WoodLog_Cecropia',
           'WoodLog_Red',
           'WoodLog_Green',
           'WoodLog_Blue',
           'WoodLog_Yellow',
           'WoodLog_White',
           'WoodLog_Black'

$natural = [Ordered]@{
    Oak      = '(185,142,96)'
    Poplar   = '(184,156,108)'
    Pine     = '(198,146,68)'
    Birch    = '(235,228,216)'
    Cecropia = '(126,74,63)'
    Teak     = '(154,102,59)'
}

$painted = [Ordered]@{
    Red      = '(200,0,0)'
    Green    = '(0,200,0)'
    Blue     = '(0,0,200)'
    Yellow   = '(200,200,0)'
    White    = '(255,255,255)'
    Black    = '(50,50,50)'
}

. "$psscriptroot/build_TerrainDefs.ps1"
. "$psscriptroot/build_ThingDefs_Buildings.ps1"
. "$psscriptroot/build_ThingDefs_Items.ps1"
. "$psscriptroot/build_ThingDefs_Plants.ps1"