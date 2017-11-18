#
# ThingDefs_Plants
#

# Base

$commonParams = @{
    DefType = 'ThingDefs*'
    SaveAs  = "$build\Defs\ThingDefs_Plants\EW-Base.xml"
}

Copy-RWModDef @commonParams -Name 'VGP Xtra Trees and Flowers\VG_PlantBase'
Copy-RWModDef @commonParams -Name 'VGP Xtra Trees and Flowers\VG_TreeBase'
Copy-RWModDef @commonParams -Name 'VGP Xtra Trees and Flowers\VG_TreewoodBase'

# Trees

$commonParams = @{
    DefType = 'ThingDefs_Plants'
    SaveAs  = "$build\Defs\ThingDefs_Plants\EW-Trees.xml"
}

foreach ($woodType in $natural) {
    Copy-RWModDef @commonParams -Name "VGP Xtra Trees and Flowers\PlantTree$woodType" -Update @{
        'plant.harvestedThingDef' = "WoodLog_$woodType"
    }
}