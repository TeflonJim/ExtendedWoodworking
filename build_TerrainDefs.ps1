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
foreach ($woodType in $natural) {
    $params = @{
        NewName = "WoodPlankFloor_$woodType"
        Update  = @{
            label                        = "$($woodType.ToLower()) wood floor"
            description                  = "$woodType plank flooring. For that warm, homey feeling."
            color                        = $colours.$woodType
            "costList.WoodLog_$woodType" = 6
            "statBases.Beauty"           = $woodStats.$woodType.StructuralBeauty
            texturePath                  = 'Floor/WoodFloorBase'
        }
    }
    Copy-RWModDef @commonParams @params
}

# Floors (Polished). Likely to need an assembly.

# $commonParams = @{
#     Name    = 'Core\WoodPlankFloor'
#     DefType = 'TerrainDefs'
#     SaveAs  = "$build\Defs\TerrainDefs\EW-Wood Floors.xml"
#     Remove  = 'CostList', 'designationHotkey'
# }
# foreach ($woodType in $natural) {
#     $params = @{
#         NewName = "WoodPlankFloor_Polished$woodType"
#         Update  = @{
#             label                        = "Polished $($woodType.ToLower()) wood floor"
#             description                  = "Polished $woodType flooring. It takes a lot of work to turn rough floor into this polished surface. Polished surfaces are easier to keep clean."
#             color                        = $colours.$woodType
#             "CostList.WoodLog_$woodType" = 0
#             "statBases.Cleanliness"      = 0.2
#             "statBases.Beauty"           = $woodStats.StructuralBeauty + 1
#             "statBases.WorkToMake"       = 1000
#             texturePath                  = 'Floor/WoodFloorBase'
#         }
#     }
#     Copy-RWModDef @commonParams @params
# }

# Floors (Painted)

$commonParams = @{
    Name    = 'Core\WoodPlankFloor'
    DefType = 'TerrainDefs'
    SaveAs  = "$build\Defs\TerrainDefs\EW-Wood Floors.xml"
    Remove  = 'CostList', 'designationHotkey'
}
foreach ($colour in $painted) {
    Copy-RWModDef @commonParams -NewName "WoodPlankFloor_$colour" -Update @{
        label                      = "$($colour.ToLower()) painted wood floor"
        description                = "$colour wood plank flooring. For that warm, homey feeling."
        color                      = $colours.$colour
        "costList.WoodLog_$colour" = 6
        "statBases.Beauty"         = 2
        texturePath                = 'Floor/WoodFloorBase'
    }
}