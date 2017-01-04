#
# ThingDefs_Plants
#

# Base

$commonParams = @{
    DefType = 'ThingDefs_Plants'
    SaveAs  = "$psscriptroot\build\Defs\ThingDefs_Plants\EW-Base.xml"
}

Copy-RWModDef @commonParams -Name 'Core\PlantBase'
Copy-RWModDef @commonParams -Name 'Core\TreeBase'

# Trees

$commonParams = @{
    DefType = 'ThingDefs_Plants'
    SaveAs  = "$psscriptroot\build\Defs\ThingDefs_Plants\EW-Trees.xml"
}

foreach ($woodType in $natural.Keys) {
    Copy-RWModDef @commonParams -Name "Core\PlantTree$woodType" -Update @{
        'plant.harvestedThingDef' = "WoodLog_$woodType"
    }
}