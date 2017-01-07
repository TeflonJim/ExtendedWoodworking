#
# ThingDefs_Buildings
#

# Base

$path = "$build\Defs\ThingDefs_Buildings\EW-Base.xml"

$commonParams = @{
    Name    = 'Core\BuildingBase'
    DefType = 'ThingDefs_Buildings'
    SaveAs  = $path
}

Copy-RWModDef @commonParams

Copy-RWModDef @commonParams -NewName 'BuildingBaseNoResources' -Remove 'leaveResourcesWhenKilled', 'filthLeaving'

$params = @{
    Name    = 'Core\DoorBase'
    DefType = 'ThingDefs_Buildings'
    SaveAs  = $path
    Remove  = 'stuffCategories'
    Update  = @{
        stuffCategories          = @('Woody')
        'statBases.MaxHitPoints' = 150
        holdsRoof                = 'false'
        blockLight               = 'false'
    }
}
Copy-RWModDef @params

# Temperature

$params = @{
    Name    = 'Core\Campfire'
    DefType = 'ThingDefs_Buildings'
    SaveAs  = "$build\Defs\ThingDefs_Buildings\EW-Temperature.xml"
    Remove  = 'costList'
    Update  = @{
        ParentName                                             = 'BuildingBaseNoResources'
        costStuffCount                                         = 30
        stuffCategories                                        = @('Woody')
        'comps.CompProperties_Refuelable.fuelFilter.thingDefs' = $allWood
    }
}
Copy-RWModDef @params

# FuelGen

$params = @{
    Name    = 'Core\FueledGenerator'
    DefType = 'ThingDefs_Buildings'
    SaveAs  = "$build\Defs\ThingDefs_Buildings\EW-Power.xml"
    Update  = @{
        'comps.CompProperties_Refuelable.fuelFilter.thingDefs' = $allWood
    }
}
Copy-RWModDef @params