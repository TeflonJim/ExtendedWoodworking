#
# ThingDefs_Items
#

# Base

$commonParams = @{
    DefType = 'ThingDefs_Items'
    SaveAs  = "$psscriptroot\build\Defs\ThingDefs_Items\EW-Base.xml"
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
    SaveAs  = "$psscriptroot\build\Defs\ThingDefs_Items\EW-WoodTypes.xml"
}

# WoodLog (generic)

Copy-RWModDef @commonParams -Update @{
    label           = 'generic wood'
    description     = "The most generic piece of wood you've ever seen. So generic you can't even tell what kind of wood it is."
    thingCategories = @('WoodTypes')
}

# Woodlog (natural)

Copy-RWModDef @commonParams -NewName 'WoodLog_Oak' -Update @{
    label                                  = 'oak wood'
    'graphicData.texPath'                  = 'Logs/WoodLog'
    'graphicData.graphicClass'             = 'Graphic_Single'
    'graphicData.color'                    = $natural.Oak
    'stuffProps.color'                     = $natural.Oak
    'stuffProps.statFactors.MaxHitPoints'  = 0.75
    'stuffProps.statFactors.Beauty'        = 2.5
    'stuffProps.statFactors.WorkToMake'    = 0.9
    'stuffProps.statFactors.DoorOpenSpeed' = 1.1
    'stuffProps.stuffAdjective'            = 'oak'
    thingCategories                        = @('WoodTypes')
}

Copy-RWModDef @commonParams -NewName WoodLog_Poplar -Update @{
    label                                  = 'poplar wood'
    'graphicData.texPath'                  = 'Logs/WoodLog'
    'graphicData.graphicClass'             = 'Graphic_Single'
    'graphicData.color'                    = $natural.Poplar
    'stuffProps.color'                     = $natural.Poplar
    'stuffProps.statFactors.MaxHitPoints'  = 0.7
    'stuffProps.statFactors.Beauty'        = 1.5
    'stuffProps.statFactors.WorkToMake'    = 0.9
    'stuffProps.statFactors.DoorOpenSpeed' = 1.2
    'stuffProps.stuffAdjective'            = 'poplar'
    thingCategories                        = @('WoodTypes')
}

Copy-RWModDef @commonParams -NewName WoodLog_Pine -Update @{
    label                                  = 'pine wood'
    'graphicData.texPath'                  = 'Logs/WoodLog'
    'graphicData.graphicClass'             = 'Graphic_Single'
    'graphicData.color'                    = $natural.Pine
    'stuffProps.color'                     = $natural.Pine
    'stuffProps.statFactors.MaxHitPoints'  = 0.6
    'stuffProps.statFactors.Beauty'        = 1.5
    'stuffProps.statFactors.WorkToMake'    = 0.7
    'stuffProps.statFactors.DoorOpenSpeed' = 1.2
    'stuffProps.stuffAdjective'            = 'pine'
    thingCategories                        = @('WoodTypes')
}

Copy-RWModDef @commonParams -NewName WoodLog_Birch -Update @{
    label                                  = 'birch wood'
    'graphicData.texPath'                  = 'Logs/WoodLog'
    'graphicData.graphicClass'             = 'Graphic_Single'
    'graphicData.color'                    = $natural.Birch
    'stuffProps.color'                     = $natural.Birch
    'stuffProps.statFactors.MaxHitPoints'  = 0.6
    'stuffProps.statFactors.Beauty'        = 1.5
    'stuffProps.statFactors.WorkToMake'    = 0.7
    'stuffProps.statFactors.DoorOpenSpeed' = 1.3
    'stuffProps.stuffAdjective'            = 'birch'
    thingCategories                        = @('WoodTypes')
}

Copy-RWModDef @commonParams -NewName WoodLog_Cecropia -Update @{
    label                                  = 'cecropia wood'
    'graphicData.texPath'                  = 'Logs/WoodLog'
    'graphicData.graphicClass'             = 'Graphic_Single'
    'graphicData.color'                    = $natural.Cecropia
    'stuffProps.color'                     = $natural.Cecropia
    'stuffProps.statFactors.MaxHitPoints'  = 0.5
    'stuffProps.statFactors.Beauty'        = 1.5
    'stuffProps.statFactors.WorkToMake'    = 0.7
    'stuffProps.statFactors.DoorOpenSpeed' = 1.2
    'stuffProps.stuffAdjective'            = 'cecropia'
    thingCategories                        = @('WoodTypes')
}

Copy-RWModDef @commonParams -NewName WoodLog_Teak -Update @{
    label                                  = 'teak wood'
    'graphicData.texPath'                  = 'Logs/WoodLog'
    'graphicData.graphicClass'             = 'Graphic_Single'
    'graphicData.color'                    = $natural.Teak
    'stuffProps.color'                     = $natural.Teak
    'stuffProps.statFactors.MaxHitPoints'  = 0.7
    'stuffProps.statFactors.Beauty'        = 1.5
    'stuffProps.statFactors.WorkToMake'    = 0.9
    'stuffProps.statFactors.DoorOpenSpeed' = 1.2
    'stuffProps.stuffAdjective'            = 'teak'
    thingCategories                        = @('WoodTypes')
}

# WoodLog (painted)

$commonParams = @{
    Name    = 'Core\WoodLog'
    DefType = 'ThingDefs_Items'
    SaveAs  = "$psscriptroot\build\Defs\ThingDefs_Items\EW-PaintedWood.xml"
}

foreach ($colour in $painted.Keys) {
    Copy-RWModDef @commonParams -NewName "WoodLog_$colour" -Update @{
        ParentName                  = 'ResourceBasePainted'
        label                       = "$($colour.ToLower()) painted wood"
        description                 = 'Wood that has been painted $($colour.ToLower()).'
        'graphicData.color'         = $painted.$colour
        'stuffProps.color'          = $painted.$colour
        'stuffProps.stuffAdjective' = 'painted'
        thingCategories             = @('WoodTypes')
    }
}