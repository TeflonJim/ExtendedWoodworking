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
    Update  = @{
        'statBases.MaxHitPoints' = 150
        holdsRoof                = 'false'
        blockLight               = 'false'
    }
}
Copy-RWModDef @params