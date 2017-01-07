#
# TerrainDefs
#

# Base

$params = @{
    Name    = 'Core\FloorBase'
    DefType = 'TerrainDefs'
    SaveAs  = "$build\Defs\TerrainDefs\EW-Base.xml"
}
Copy-RWModDef @params

# Floors (natural)

$commonParams = @{
    Name    = 'Core\WoodPlankFloor'
    DefType = 'TerrainDefs'
    SaveAs  = "$build\Defs\TerrainDefs\EW-Wood Floors.xml"
    Remove  = 'CostList', 'designationHotkey'
}
foreach ($woodType in $natural) {
    $params = @{
        NewName = "WoodPlankFloor_$woodType"
        Update  = @{
            label                        = "$($woodType.ToLower()) wood floor"
            description                  = "$woodType plank flooring. For that warm, homey feeling."
            color                        = $colours.$woodType
            "CostList.WoodLog_$woodType" = 6
            texturePath                  = 'Floor/WoodFloorBase'
        }
    }
    Copy-RWModDef @commonParams @params
}

# Floors (Painted)

$path = "$build\Defs\TerrainDefs\EW-Wood Floors.xml"

$commonParams = @{
    Name    = 'Core\WoodPlankFloor'
    DefType = 'TerrainDefs'
    SaveAs  = $path
    Remove  = 'CostList', 'designationHotkey'
}
foreach ($colour in $painted) {
    Copy-RWModDef @commonParams -NewName "WoodPlankFloor_$colour" -Update @{
        label                      = "$($colour.ToLower()) painted wood floor"
        description                = "$colour wood plank flooring. For that warm, homey feeling."
        color                      = $colours.$colour
        "CostList.WoodLog_$colour" = 6
        texturePath                = 'Floor/WoodFloorBase'
    }
}