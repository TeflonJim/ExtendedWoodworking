#
# ThingDefs_Items
#

# Base

$commonParams = @{
    DefType = 'ThingDefs_Items'
    SaveAs  = "$build\Defs\ThingDefs_Items\EW-Base.xml"
}

Copy-RWModDef @commonParams -Name 'Core\ResourceBase'

$params = @{
    Name    = 'Core\ResourceBase'
    NewName = 'ResourceBasePainted'
    Update  = @{
        'graphicData.texPath'      = 'Logs/WoodLog'
        'graphicData.graphicClass' = 'Graphic_Single'
    }
}
Copy-RWModDef @commonParams @params

Copy-RWModDef @commonParams -Name 'Core\ResourceVerbBase'

# Wood types

$commonParams = @{
    Name    = 'Core\WoodLog'
    DefType = 'ThingDefs_Items'
    SaveAs  = "$build\Defs\ThingDefs_Items\EW-WoodTypes.xml"
}

# WoodLog (generic)

Copy-RWModDef @commonParams -Update @{
    label           = 'generic wood'
    description     = "The most generic piece of wood you've ever seen. So generic you can't even tell what kind of wood it is."
    thingCategories = @('WoodTypes')
}

# Woodlog (natural)

foreach ($woodType in $woodStats.Keys) {
    Copy-RWModDef @commonParams -NewName "WoodLog_$woodType" -Update @{
        label                                  = '{0} wood' -f $woodType
        'graphicData.texPath'                  = 'Logs/WoodLog'
        'graphicData.graphicClass'             = 'Graphic_Single'
        'graphicData.color'                    = $woodStats[$woodType].Colour
        'stuffProps.color'                     = $woodStats[$woodType].Colour
        'stuffProps.statFactors.MaxHitPoints'  = $woodStats[$woodType].MaxHitPoints
        'stuffProps.statFactors.Beauty'        = $woodStats[$woodType].StructuralBeauty
        'stuffProps.statFactors.WorkToMake'    = $woodStats[$woodType].WorkToMake
        'stuffProps.statFactors.DoorOpenSpeed' = $woodStats[$woodType].DoorOpenSpeed
        'stuffProps.stuffAdjective'            = $woodType.ToLower()
        thingCategories                        = @('WoodTypes')
    }
}

# WoodLog (painted)

$commonParams = @{
    Name    = 'Core\WoodLog'
    DefType = 'ThingDefs_Items'
    SaveAs  = "$build\Defs\ThingDefs_Items\EW-PaintedWood.xml"
}

foreach ($colour in $painted.Keys) {
    Copy-RWModDef @commonParams -NewName "WoodLog_$colour" -Update @{
        ParentName                  = 'ResourceBasePainted'
        label                       = '{0} painted wood' -f $colour
        description                 = 'Wood that has been painted {0}' -f $colour.ToLower()
        'graphicData.color'         = $painted[$colour]
        'stuffProps.color'          = $painted[$colour]
        'stuffProps.stuffAdjective' = 'painted'
        thingCategories             = @('WoodTypes')
    }
}