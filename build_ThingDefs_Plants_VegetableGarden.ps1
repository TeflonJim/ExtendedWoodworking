#
# ThingDefs_Plants
#

# Base

$commonParams = @{
    DefType = 'ThingDefs'
    SaveAs  = "$build\Defs\ThingDefs_Plants\EW-Base.xml"
}

Copy-RWModDef @commonParams -Name 'Vegetable Garden\VG_PlantBase'
Copy-RWModDef @commonParams -Name 'Vegetable Garden\VG_TreeBase'
Copy-RWModDef @commonParams -Name 'Vegetable Garden\VG_TreewoodBase'

# Trees

$commonParams = @{
    DefType = 'ThingDefs_Plants'
    SaveAs  = "$build\Defs\ThingDefs_Plants\EW-Trees.xml"
}

foreach ($woodType in $natural) {
    Copy-RWModDef @commonParams -Name "Vegetable Garden\PlantTree$woodType" -Update @{
        'plant.harvestedThingDef' = "WoodLog_$woodType"
    }
}