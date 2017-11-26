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
    Remove  = 'costList', 'designationHotkey'
}
foreach ($woodType in $woodStats.Keys) {
    $params = @{
        NewName = "WoodPlankFloor_$woodType"
        Update  = @{
            label                        = "$($woodType.ToLower()) wood floor"
            description                  = "$woodType plank flooring. For that warm, homey feeling."
            color                        = $woodStats[$woodType].Colour
            "costList.WoodLog_$woodType" = 6
            "statBases.Beauty"           = $woodStats[$woodType].StructuralBeauty
            texturePath                  = 'Floor/WoodFloorBase'
        }
    }
    Copy-RWModDef @commonParams @params
}

# Floors (Painted)

$commonParams = @{
    Name    = 'Core\WoodPlankFloor'
    DefType = 'TerrainDefs'
    SaveAs  = "$build\Defs\TerrainDefs\EW-Wood Floors.xml"
    Remove  = 'CostList', 'designationHotkey'
}
foreach ($colour in $painted.Keys) {
    Copy-RWModDef @commonParams -NewName "WoodPlankFloor_$colour" -Update @{
        label                      = "$($colour.ToLower()) painted wood floor"
        description                = "$colour wood plank flooring. For that warm, homey feeling."
        color                      = $painted[$colour]
        "costList.WoodLog_$colour" = 6
        "statBases.Beauty"         = 2
        texturePath                = 'Floor/WoodFloorBase'
    }
}