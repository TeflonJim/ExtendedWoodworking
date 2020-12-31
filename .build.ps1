#Requires -Module Indented.RimWorld

param (
    [ValidateSet('Major', 'Minor', 'Build')]
    [String]$ReleaseType = 'Build'
)

task Build @(
    'Setup'
    'ValidateSupportedMods'
    'UpdateLastVersion'
    'Clean'
    'CopyFramework'
    'SetPublishedItemID'
    'UpdateRecipeDefs'
    'UpdateTerrainDefs'
    'UpdateThingDefsBuildings'
    'UpdateThingDefsItems'
    'CreateHarvestedThingDefPatch'
    'CreateCostListPatch'
    'CreateRecipeDefPatch'
    'CreateWoodLogPatch'
    'CreateWoodFloorPatch'
    'CreateFloorPatches'
    'CleanPatches'
    'UpdateVersion'
    'CreatePackage'
    'UpdateLocal'
)

function ConvertTo-OrderedDictionary {
    process {
        $dictionary = [Ordered]@{}
        foreach ($name in $_.PSObject.Properties.Name) {
            $dictionary.$name = $_.$name
        }
        $dictionary
    }
}

task Setup {
    $Global:buildInfo = [PSCustomObject]@{
        Name            = 'Extended Woodworking'
        PublishedFileID = '836912371'
        Version         = $null
        RimWorldVersion = $rwVersion = Get-RWVersion
        Path            = [PSCustomObject]@{
            Build            = Join-Path -Path $psscriptroot -ChildPath 'build'
            Generated        = $generatedPath = Join-Path -Path $psscriptroot -ChildPath 'generated\Extended Woodworking'
            GeneratedVersion = Join-Path -Path $generatedPath -ChildPath $rwVersion.ShortVersion
            Source           = $source = Join-Path -Path $psscriptroot -ChildPath 'source'
            Template         = Join-Path -Path $source -ChildPath 'template'
            About            = Join-Path -Path $source -ChildPath 'About\About.xml'
        }
        Data    = [PSCustomObject]@{
            WoodPainted        = Get-Content (Join-Path -Path $psscriptroot -ChildPath 'woodPainted.json') | ConvertFrom-Json | ConvertTo-OrderedDictionary
            WoodStats          = Get-Content (Join-Path -Path $psscriptroot -ChildPath 'woodStats.json') | ConvertFrom-Json | ConvertTo-OrderedDictionary
            SupportedMods      = @(
                'Core'
                'Royalty'
                '[SYR] Universal Fermenter'
                '[T] MoreFloors'
                'A Dog Said... Animal Prosthetics'
                'A RimWorld of Magic'
                'Area Rugs'
                'Expanded Prosthetics and Organ Engineering'
                'Fertile Fields'
                'GloomyFurniture'
                'Misc. Training'
                'VGP Xtra Trees and Flowers'
            )
            SupportedFloorMods = @(
                'Evt Floors'
                '[T] MoreFloors'
                '[WD] Expanded Floors'
                'GloomyFurniture'
                'RIMkea'
            )
            SkipFloorDefs = @(
                '*Light_Evt*'
                '*Dark_Evt*'
            )
        }
    }
    $path = Join-Path $psscriptroot 'source\About\Manifest.xml'
    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $buildInfo.Version = [Version]$xDocument.Element('Manifest').Element('version').Value
}

# Synopsis: Ensures a local copy exists of each mod
task ValidateSupportedMods {
    $missingMods = $buildInfo.Data.SupportedMods + $buildInfo.Data.SupportedFloorMods |
        Select-Object -Unique |
        Where-Object { -not (Get-RWMod -Name $_) }

    if ($missingMods) {
        throw 'Cannot find mod(s) required for patch generation: {0}' -f ($missingMods -join ', ')
    }
}

# Synopsis: Makes the last generated module content permanent if RimWorlds short version increments.
task UpdateLastVersion {
    $aboutXml = [System.Xml.Linq.XDocument]::Load($buildInfo.Path.About)
    $supportedVersionsNode = $aboutXml.Element('ModMetaData').Element('supportedVersions')

    $supportedVersions = $supportedVersionsNode.Elements('li').Value -as [Version[]] | Sort-Object

    if ($buildInfo.RimWorldVersion.ShortVersion -notin $supportedVersions) {
        $lastVersion = $supportedVersions[-1]
        $path = Join-Path -Path $buildInfo.Path.Source -ChildPath $lastVersion

        if (-not (Test-Path $path)) {
            $contentToArchive = Join-Path -Path $buildInfo.Path.Generated -ChildPath $lastVersion

            if (Test-Path $contentToArchive) {
                Copy-Item -Path $contentToArchive -Destination $buildInfo.Path.Source -Recurse -Force
            }
        }

        $supportedVersionsNode.Add(
            [System.Xml.Linq.XElement]::new(
                [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]'li', $buildInfo.RimWorldVersion.ShortVersion)
            )
        )

        $aboutXml.Save($buildInfo.Path.About)
    }
}

task UpdateLoadOrder {
    $loadAfterNode = [System.Xml.Linq.XElement]::new(
        [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]'loadAfter')
    )

    foreach ($mod in $buildInfo.Data.SupportedMods + $buildInfo.Data.SupportedFloorMods) {
        if ($mod = Get-RWMod -Name $mod) {
            if ($mod.PackageId) {
                $loadAfterNode.Add(
                    [System.Xml.Linq.XElement]::new(
                        [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]'li', $mod.PackageId)
                    )
                )
            }
        }
    }

    $aboutXml = [System.Xml.Linq.XDocument]::Load($buildInfo.Path.About)
    $aboutXml.Element('ModMetaData').Element('loadAfter').ReplaceWith($loadAfterNode)

    $aboutXml.Save($buildInfo.Path.About)
}

task Clean {
    if (Test-Path $buildInfo.Path.Build) {
        Remove-Item $buildInfo.Path.Build -Recurse
    }
    if (Test-Path $buildInfo.Path.Generated) {
        Remove-Item $buildInfo.Path.Generated -Recurse
    }
    New-Item $buildInfo.Path.Build -ItemType Directory
    New-Item $buildInfo.Path.GeneratedVersion -ItemType Directory
}

task CopyFramework {
    Get-ChildItem -Path $buildInfo.Path.Source -Exclude template | Copy-Item -Destination $buildInfo.Path.Generated -Recurse
    Join-Path -Path $buildInfo.Path.Source -ChildPath 'template\*' | Copy-Item -Destination $buildInfo.Path.GeneratedVersion -Recurse
}

task SetPublishedItemID {
    Set-Content (Join-Path $buildInfo.Path.Generated 'About\PublishedFileId.txt') -Value $buildInfo.PublishedFileID
}

task UpdateRecipeDefs {
    $path = Join-Path $buildInfo.Path.GeneratedVersion 'Defs\RecipeDefs\EW-Woodworking.xml'

    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $template = $xDocument.Root.Elements('RecipeDef').Where( { $_.Element('defName').Value -eq 'PaintWoodLogTemplate' } )[0]

    foreach ($colour in $buildInfo.Data.WoodPainted.Keys) {
        $recipe = [System.Xml.Linq.XElement]::new($template)

        $recipe.Element('defName').SetValue("PaintWoodLog_$colour")
        $recipe.Element('label').SetValue(('paint wood {0}' -f $colour.ToLower()))
        $recipe.Element('description').SetValue(('Paints wood {0}' -f $colour.ToLower()))
        $recipe.Element('products').Add(
            [System.Xml.Linq.XElement]::new(
                [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]"WoodLog_$colour", 25)
            )
        )
        $buildInfo.Data.WoodPainted.Keys | Where-Object { $_ -ne $colour } | ForEach-Object {
            $recipe.Element('defaultIngredientFilter').
                    Element('disallowedThingDefs').
                    Add(
                        [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]'li', "WoodLog_$_")
                    )
        }

        $xDocument.Root.Add($recipe)
    }

    # Remove the template
    $template.Remove()
    $xDocument.Save($path)
}

task UpdateTerrainDefs {
    Write-Verbose 'Copying FloorBase'

    $params = @{
        Name    = 'Core\FloorBase'
        SaveAs  = Join-Path $buildInfo.Path.GeneratedVersion 'Defs\TerrainDefs\EW-Base.xml'
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }
    Copy-RWModDef @params

    # Floors (natural)

    $path = Join-Path $buildInfo.Path.GeneratedVersion 'Defs\TerrainDefs\EW-WoodFloors.xml'

    $commonParams = @{
        Name    = 'Core\WoodPlankFloor'
        SaveAs  = $path
        Remove  = 'costList', 'designationHotKey'
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }
    foreach ($woodType in $buildInfo.Data.WoodStats.Keys) {
        Write-Verbose ('Copying {0} floor' -f $woodType)

        $wood = $buildInfo.Data.WoodStats[$woodType]

        if ($buildInfo.Data.WoodStats[$woodType].Mod) {
            continue
        }

        $params = @{
            NewName = 'WoodPlankFloor_{0}' -f $woodType
            Update  = @{
                label                                 = '{0} wood floor' -f $woodType.ToLower()
                description                           = '{0} plank flooring. For that warm, homey feeling.' -f $wood.DescriptiveName
                color                                 = $wood.Colour
                ('costList.WoodLog_{0}' -f $woodType) = 6
                'statBases.Beauty'                    = $wood.StructuralBeauty
                'designatorDropdown'                  = 'Floor_WoodPlank'
                texturePath                           = 'Floor/WoodFloorBase'
            }
        }
        Copy-RWModDef @commonParams @params
    }

    # Floors (Painted)

    $commonParams = @{
        Name    = 'Core\WoodPlankFloor'
        SaveAs  = $path
        Remove  = 'costList', 'designationHotKey'
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }
    foreach ($colour in $buildInfo.Data.WoodPainted.Keys) {
        Write-Verbose ('Generating {0} painted floor' -f $colour)

        $wood = $buildInfo.Data.WoodPainted[$colour]

        $params = @{
            NewName = 'WoodPlankFloor_{0}' -f $colour
            Update  = @{
                label                               = '{0} painted wood floor' -f $colour.ToLower()
                description                         = '{0} wood plank flooring. For that warm, homey feeling.' -f $colour
                color                               = $wood
                ('costList.WoodLog_{0}' -f $colour) = 6
                "statBases.Beauty"                  = 2
                'designatorDropdown'                = 'Floor_WoodPlank'
                texturePath                         = 'Floor/WoodFloorBase'
            }
        }
        Copy-RWModDef @commonParams @params
    }
}

task UpdateThingDefsBuildings {
    $path = Join-Path $buildInfo.Path.GeneratedVersion 'Defs\ThingDefs_Buildings\EW-Base.xml'

    $commonParams = @{
        Name    = 'Core\BuildingBase'
        SaveAs  = $path
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }
    Copy-RWModDef @commonParams
    Copy-RWModDef @commonParams -NewName 'BuildingBaseNoResources' -Remove 'leaveResourcesWhenKilled', 'filthLeaving'

    $params = @{
        Name    = 'Core\DoorBase'
        SaveAs  = $path
        Update  = @{
            'statBases.MaxHitPoints' = 150
            holdsRoof                = 'false'
            blockLight               = 'false'
        }
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }
    Copy-RWModDef @params
}

task UpdateThingDefsItems {
    $commonParams = @{
        SaveAs  = Join-Path $buildInfo.Path.GeneratedVersion 'Defs\ThingDefs_Items\EW-Base.xml'
        Version = $buildInfo.RimWorldVersion.ShortVersion
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
        SaveAs  = Join-Path $buildInfo.Path.GeneratedVersion 'Defs\ThingDefs_Items\EW-WoodTypes.xml'
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }

    # WoodLog (generic)

    Copy-RWModDef @commonParams -Update @{
        label           = 'generic wood'
        description     = "The most generic piece of wood you've ever seen. So generic you can't even tell what kind of wood it is."
        thingCategories = @('WoodTypes')
    }

    # Woodlog (natural)

    foreach ($woodType in $buildInfo.Data.WoodStats.Keys) {
        $wood = $buildInfo.Data.WoodStats[$woodType]

        if ($wood.Mod) {
            continue
        }

        $params = @{
            NewName = 'WoodLog_{0}' -f $woodType
            Update  = @{
                label                                  = '{0} wood' -f $woodType
                'graphicData.texPath'                  = 'Logs/WoodLog'
                'graphicData.graphicClass'             = 'Graphic_Single'
                'graphicData.color'                    = $wood.Colour
                'stuffProps.color'                     = $wood.Colour
                'stuffProps.statFactors.MaxHitPoints'  = $wood.MaxHitPoints
                'stuffProps.statFactors.Beauty'        = $wood.StructuralBeauty
                'stuffProps.statFactors.WorkToMake'    = $wood.WorkToMake
                'stuffProps.statFactors.DoorOpenSpeed' = $wood.DoorOpenSpeed
                'stuffProps.stuffAdjective'            = $woodType.ToLower()
                thingCategories                        = @('WoodTypes')
            }
        }
        Copy-RWModDef @commonParams @params
    }

    # WoodLog (painted)

    $commonParams = @{
        Name    = 'Core\WoodLog'
        SaveAs  = Join-Path $buildInfo.Path.GeneratedVersion 'Defs\ThingDefs_Items\EW-PaintedWood.xml'
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }

    foreach ($colour in $buildInfo.Data.WoodPainted.Keys) {
        $wood = $buildInfo.Data.WoodPainted[$colour]

        $params = @{
            NewName = 'WoodLog_{0}' -f $colour
            Update  = @{
                ParentName                  = 'ResourceBasePainted'
                label                       = '{0} painted wood' -f $colour
                description                 = 'Wood that has been painted {0}' -f $colour.ToLower()
                'graphicData.color'         = $wood
                'stuffProps.color'          = $wood
                'stuffProps.stuffAdjective' = $colour.ToLower()
                thingCategories             = @('WoodTypes')
            }
        }
        Copy-RWModDef @commonParams @params
    }
}

task CreateCostListPatch {
    foreach ($mod in $buildInfo.Data.SupportedMods) {
        $modInfo = Get-RWMod $mod
        $shortName = $mod -replace '[^A-Za-z0-9]'

        Get-ChildItem (Join-Path $modInfo.Path 'Defs') -Filter *.xml -Recurse | ForEach-Object {
            $item = $_

            $xDocument = [System.Xml.Linq.XDocument]::Load($item.FullName)
            [System.Xml.XPath.Extensions]::XPathSelectElements(
                $xDocument,
                '/Defs/*[name()!="TerrainDef" and defName and not(stuffCategories) and ./costList/WoodLog]'
            )
        } | ForEach-Object {
            [PSCustomObject]@{
                Mod  = $shortName
                Node = $_
            }
        } | Group-Object Mod | ForEach-Object {
            $newName = 'Patches/EW-%MOD%-costList.xml' -replace '%MOD%', $_.Name
            $newPath = Join-Path $buildInfo.Path.GeneratedVersion $newName
            if ($_.Name -eq 'Core') {
                $template = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches/EW-CORE-costList.xml'
            } else {
                $template = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches/EW-%MOD%-costList.xml'
            }

            Copy-Item $template $newPath -Force

            $xDocument = [System.Xml.Linq.XDocument]::Load($newPath)
            $xDocument.Descendants('mods') | ForEach-Object {
                $_.Element('li').Value = (Get-RWMod -Name $mod).RawName
            }

            $template = $xDocument.Root.Element('Operation')

            foreach ($item in $_.Group) {
                foreach ($templateItem in $template) {
                    $xmlString = $templateItem.ToString() -replace '%NAME%', $item.Node.Element('defName').Value
                    $xmlString = $xmlString -replace '%COST%', $item.Node.Element('costList').Element('WoodLog').Value

                    $xElement = [System.Xml.Linq.XElement]::new($xmlString)
                    $xDocument.Root.Add($xElement)
                }
            }

            $template.ForEach{ $_.Remove() }

            $xDocument.Save($newPath)
        }
    }
}

task CreateRecipeDefPatch {
    foreach ($mod in $buildInfo.Data.SupportedMods) {
        $modInfo = Get-RWMod $mod
        $shortName = $mod -replace '[^A-Za-z0-9]'

        Get-ChildItem (Join-Path $modInfo.Path 'Defs') -Filter *.xml -Recurse | ForEach-Object {
            $item = $_

            $xDocument = [System.Xml.Linq.XDocument]::Load($item.FullName)
            [System.Xml.XPath.Extensions]::XPathSelectElements(
                $xDocument,
                '/Defs/RecipeDef[(@Abstract="False" or not(@Abstract)) and (ingredients/li/filter/thingDefs/li="WoodLog" or fixedIngredientFilter/thingDefs/li="WoodLog")]'
            )
        } | ForEach-Object {
            [PSCustomObject]@{
                Mod  = $shortName
                Node = $_
            }
        } | Group-Object Mod | ForEach-Object {
            $newName = 'Patches/EW-%MOD%-ingredients.xml' -replace '%MOD%', $_.Name
            $newPath = Join-Path $buildInfo.Path.GeneratedVersion $newName
            if ($_.Name -eq 'Core') {
                $template = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches/EW-CORE-ingredients.xml'
            } else {
                $template = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches/EW-%MOD%-ingredients.xml'
            }

            Copy-Item $template $newPath -Force

            $xDocument = [System.Xml.Linq.XDocument]::Load($newPath)
            $xDocument.Descendants('mods') | ForEach-Object {
                $_.Element('li').Value = (Get-RWMod -Name $mod).RawName
            }

            $template = $xDocument.Root.Element('Operation')

            foreach ($item in $_.Group) {
                if ($element = $item.Node.Element('defName')) {
                    $defName = $element.Value
                } elseif ($attribute = $item.Node.Attribute('Name')) {
                    $defName = $attribute.Value
                }

                foreach ($templateItem in $template) {
                    $xmlString = $templateItem.ToString() -replace '%NAME%', $defName
                    $count = [System.Xml.XPath.Extensions]::XPathSelectElements(
                        $item.Node,
                        'ingredients/li[filter/thingDefs/li="WoodLog"]/count'
                    ).Value
                    $xmlString = $xmlString -replace '%COUNT%', $count

                    $xElement = [System.Xml.Linq.XElement]::new($xmlString)
                    $xDocument.Root.Add($xElement)
                }
            }

            $template.ForEach{ $_.Remove() }

            $xDocument.Save($newPath)
        }
    }
}

task CreateHarvestedThingDefPatch {
    foreach ($mod in $buildInfo.Data.SupportedMods) {
        $modInfo = Get-RWMod $mod
        $shortName = $mod -replace '[^A-Za-z0-9]'

        Get-ChildItem (Join-Path $modInfo.Path 'Defs') -Filter *.xml -Recurse | ForEach-Object {
            $item = $_

            $xDocument = [System.Xml.Linq.XDocument]::Load($item.FullName)
            $xDocument.Descendants('defName').Where{
                $_.Value -match 'Plant_Tree' -and
                $buildInfo.Data.woodStats.Contains($_.Value -replace 'Plant_Tree')
            }.ForEach{
                [PSCustomObject]@{
                    Mod      = $shortName
                    Name     = $_.Value -replace 'Plant_Tree'
                }
            }
        } | Group-Object Mod | ForEach-Object {
            $newName = 'Patches/EW-%MOD%-harvestedThingDef.xml' -replace '%MOD%', $_.Name
            $newPath = Join-Path $buildInfo.Path.GeneratedVersion $newName
            if ($_.Name -eq 'Core') {
                $template = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches/EW-CORE-harvestedThingDef.xml'
            } else {
                $template = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches/EW-%MOD%-harvestedThingDef.xml'
            }

            Copy-Item $template $newPath -Force

            $xDocument = [System.Xml.Linq.XDocument]::Load($newPath)
            $xDocument.Descendants('mods') | ForEach-Object {
                $_.Element('li').Value = (Get-RWMod -Name $mod).RawName
            }

            $template = $xDocument.Descendants().Where{ $_.Attribute('Class').Value -eq 'PatchOperationAdd' }[0]

            foreach ($item in $_.Group) {
                $xmlString = $template.ToString() -replace '%NAME%', $item.Name

                $xElement = [System.Xml.Linq.XElement]::new($xmlString)

                $xDocument.Descendants('operations')[0].Add($xElement)
            }

            $template.Remove()

            $xDocument.Save($newPath)
        }
    }
}

task CreateWoodLogPatch {
    $commonParams = @{
        Name    = 'Core\WoodLog'
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }

    $templatePath = Join-Path $buildInfo.Path.GeneratedVersion 'Patches\EW-%MOD%-woodLog.xml'
    $buildInfo.Data.WoodStats.Keys | Where-Object { $buildInfo.Data.WoodStats[$_].Mod } | ForEach-Object {
        [PSCustomObject]@{
            Mod  = $buildInfo.Data.WoodStats[$_].Mod
            Name = $_
        }
    } | Group-Object Mod | ForEach-Object {
        $mod = $_.Name
        $shortName = $mod -replace '[^A-Za-z0-9]'

        $path = Join-Path $buildInfo.Path.GeneratedVersion ('Patches\EW-{0}-woodLog.xml' -f $shortName)
        if (-not (Test-Path $path)) {
            Copy-Item $templatePath $path
        }

        $xDocument = [System.Xml.Linq.XDocument]::Load($path)
        $xDocument.Descendants('mods').ForEach{ $_.Element('li').Value = (Get-RWMod -Name $mod).RawName }

        $template = [System.Xml.XPath.Extensions]::XPathSelectElements(
            $xDocument,
            '//li[@Class="PatchOperationAdd"]'
        ) | ForEach-Object { $_ }

        foreach ($item in $_.Group.Name) {
            $params = @{
                NewName = 'WoodLog_{0}' -f $item
                Update  = @{
                    label                                  = '{0} wood' -f $item
                    'graphicData.texPath'                  = 'Logs/WoodLog'
                    'graphicData.graphicClass'             = 'Graphic_Single'
                    'graphicData.color'                    = $buildInfo.Data.WoodStats[$item].Colour
                    'stuffProps.color'                     = $buildInfo.Data.WoodStats[$item].Colour
                    'stuffProps.statFactors.MaxHitPoints'  = $buildInfo.Data.WoodStats[$item].MaxHitPoints
                    'stuffProps.statFactors.Beauty'        = $buildInfo.Data.WoodStats[$item].StructuralBeauty
                    'stuffProps.statFactors.WorkToMake'    = $buildInfo.Data.WoodStats[$item].WorkToMake
                    'stuffProps.statFactors.DoorOpenSpeed' = $buildInfo.Data.WoodStats[$item].DoorOpenSpeed
                    'stuffProps.stuffAdjective'            = $item.ToLower()
                    thingCategories                        = @('WoodTypes')
                }
            }
            $def = (Copy-RWModDef @commonParams @params).Root

            $patch = [System.Xml.Linq.XElement]::new($template)
            $patch.Descendants('value')[0].Add($def)

            $xDocument.Descendants('operations')[0].Add($patch)
        }

        $template.Remove()
        $xDocument.Save($path)
    }
}

task CreateWoodFloorPatch {
    $commonParams = @{
        Name    = 'Core\WoodPlankFloor'
        Remove  = 'costList', 'designationHotKey'
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }

    $templatePath = Join-Path $buildInfo.Path.GeneratedVersion 'Patches\EW-%MOD%-woodFloor.xml'
    $buildInfo.Data.WoodStats.Keys | Where-Object { $buildInfo.Data.WoodStats[$_].Mod } | ForEach-Object {
        [PSCustomObject]@{
            Mod  = $buildInfo.Data.WoodStats[$_].Mod
            Name = $_
        }
    } | Group-Object Mod | ForEach-Object {
        $mod = $_.Name
        $shortName = $mod -replace '[^A-Za-z0-9]'

        $path = Join-Path $buildInfo.Path.GeneratedVersion ('Patches\EW-{0}-woodFloor.xml' -f $shortName)
        if (-not (Test-Path $path)) {
            Copy-Item $templatePath $path
        }

        $xDocument = [System.Xml.Linq.XDocument]::Load($path)
        $xDocument.Descendants('mods').ForEach{ $_.Element('li').Value = (Get-RWMod -Name $mod).RawName }

        $template = [System.Xml.XPath.Extensions]::XPathSelectElements(
            $xDocument,
            '//li[@Class="PatchOperationAdd"]'
        ) | ForEach-Object { $_ }

        foreach ($item in $_.Group.Name) {
            $wood = $buildInfo.Data.WoodStats[$item]

            $params = @{
                NewName = 'WoodPlankFloor_{0}' -f $item
                Update  = @{
                    label                             = '{0} wood floor' -f $item.ToLower()
                    description                       = '{0} plank flooring. For that warm, homey feeling.' -f $item
                    color                             = $wood.Colour
                    ('costList.WoodLog_{0}' -f $item) = 6
                    'statBases.Beauty'                = $wood.StructuralBeauty
                    'designatorDropdown'              = 'Floor_WoodPlank'
                    texturePath                       = 'Floor/WoodFloorBase'
                }
            }
            $def = (Copy-RWModDef @commonParams @params).Root

            $patch = [System.Xml.Linq.XElement]::new($template)
            $patch.Descendants('value')[0].Add($def)

            $xDocument.Descendants('operations')[0].Add($patch)
        }

        $template.Remove()
        $xDocument.Save($path)
    }
}

function CreateFloorPatch {
    param (
        [String]$FromMod,

        [String]$TreeMod
    )

    $modInfo = Get-RWMod $FromMod
    $shortModName = $modInfo.Name -replace '[^A-Za-z0-9]'

    $treeModInfo = Get-RWMod $TreeMod
    $shortTreeModName = $treeModInfo.Name -replace '[^A-Za-z0-9]'

    $templatePath = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches\EW-%MOD%-woodFloor.xml'
    $path = Join-Path $buildInfo.Path.GeneratedVersion ('Patches\EW-{0}-woodFloor.xml' -f @(
        $shortModName
    ))
    if ($TreeMod) {
        $templatePath = Join-Path -Path $buildInfo.Path.Template -ChildPath 'Patches\EW-%MOD%-%TREEMOD%-woodFloor.xml'
        $path = Join-Path $buildInfo.Path.GeneratedVersion ('Patches\EW-{0}-{1}-woodFloor.xml' -f @(
            $shortModName
            $shortTreeModName
        ))
    }

    Copy-Item -Path $templatePath -Destination $path

    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $xDocument.Element('Patch').Element('Operation').Element('mods').Element('li').Value = $modInfo.RawName
    if ($TreeMod) {
        $xDocument.Element('Patch').Element('Operation').Element('match').Element('mods').Element('li').Value = $treeModInfo.RawName
    }

    $operationsElement = $xDocument.Descendants('operations').ForEach{ $_ }[0]
    $templateElement = $operationsElement.Element('li')

    $modInfo | Get-RWModDef -Version $buildInfo.RimWorldVersion.ShortVersion | Group-Object Path -NoElement | ForEach-Object {
        $item = Get-Item $_.Name

        $cachedAbstracts = @{}
        $modXDocument = [System.Xml.Linq.XDocument]::Load($item.FullName)
        $modXDocument.Element('Defs').Elements('TerrainDef') |
            Where-Object {
                $_.Attribute('Abstract').Value -eq 'True' -and
                $_.Element('costList') -and
                $_.Element('costList').Element('WoodLog')
            } |
            ForEach-Object {
                $defName = $_.Element('defName').Value
                if (-not $defName) {
                    $defName = $_.Attribute('Name').Value
                }
                if (-not $defName) {
                    return
                }

                $cachedAbstracts.Add(
                    $defName,
                    $_
                )
            }

        $modXDocument.Element('Defs').Elements('TerrainDef') |
            Where-Object {
                $_.Attribute('Abstract').Value -ne 'True' -and
                $_.Element('defName').Value -ne 'WoodPlankFloor' -and
                (
                    (
                        $_.Element('costList') -and
                        $_.Element('costList').Element('WoodLog')
                    ) -or
                    (
                        $_.Attribute('ParentName') -and
                        $cachedAbstracts.Contains($_.Attribute('ParentName').Value)
                    )
                )
            } |
            ForEach-Object {
                $defName = $_.Element('defName').Value
                if (-not $defName) {
                    $defName = $_.Attribute('Name').Value
                }
                if (-not $defName) {
                    Write-Warning ('Cannot find defName in {0}' -f $item.FullName)
                    return
                }
                if ($buildInfo.Data.SkipFloorDefs | Where-Object { $defName -like $_ }) {
                    return
                }

                $mergedDef = $null
                if ($cachedAbstracts.Contains($_.Attribute('ParentName').Value)) {
                    $mergedDef = $_
                    $abstractDef = $cachedAbstracts[$_.Attribute('ParentName').Value]
                    $mergedDef.Attribute('ParentName').Value = $abstractDef.Attribute('ParentName').Value

                    $abstractDef.Elements() | ForEach-Object {
                        if (-not $mergedDef.Element($_.Name)) {
                            $mergedDef.Add($_)
                        }
                    }
                }

                if (-not $TreeMod) {
                    $xElement = [System.Xml.Linq.XElement]::new($templateElement.ToString())
                    $xElement.Element('value').Add(
                        [System.Xml.Linq.XElement]::new(
                            [System.Xml.Linq.XName]'DesignatorDropdownGroupDef',
                            [System.Xml.Linq.XElement]::new(
                                [System.Xml.Linq.XName]'defName',
                                'Floor_{0}' -f $defName
                            )
                        )
                    )
                    $operationsElement.Add($xElement)

                    $xElement = [System.Xml.Linq.XElement]::new($templateElement.ToString())
                    $xElement.Element('xpath').Value = '/Defs/TerrainDef[defName="{0}"]' -f $defName
                    $xElement.Element('value').Add(
                        [System.Xml.Linq.XElement]::new(
                            [System.Xml.Linq.XName]'designatorDropdown',
                            'Floor_{0}' -f $defName
                        )
                    )
                    $operationsElement.Add($xElement)
                }

                foreach ($woodType in $buildInfo.Data.WoodStats.Keys) {
                    $wood = $buildInfo.Data.WoodStats[$woodType]

                    if ((-not $TreeMod -and $wood.Mod) -or ($TreeMod -and $wood.Mod -ne $TreeMod)) {
                        continue
                    }

                    $label = $_.Element('label').Value -replace 'wood(en)?', $woodType.ToLower()
                    if ($label -notmatch $woodType) {
                        $label = '{0} {1}' -f $woodType.ToLower(), $label
                    }

                    $params = @{
                        Name    = '{0}\{1}' -f $mod, $defName
                        NewName = '{0}_{1}' -f $defName, $woodType
                        DefType = 'TerrainDef'
                        Update  = @{
                            label                                 = $label
                            description                           = $_.Element('description').Value -replace 'wood(en)?', $wood.DescriptiveName.ToLower()
                            color                                 = $wood.Colour
                            ('costList.WoodLog_{0}' -f $woodType) = $_.Element('costList').Element('WoodLog').Value
                            'designatorDropdown'                  = 'Floor_{0}' -f $defName
                        }
                        Remove  = 'costList'
                        Version = $buildInfo.RimWorldVersion.ShortVersion
                    }
                    $params.Update.description = $params.Update.description -replace '^.', $params.Update.description.Substring(0, 1).ToUpper()
                    if ($mergedDef) {
                        $params.Remove('Name')
                        $params.Remove('DefType')
                        $params.Remove('Version')
                        $params.Def = $mergedDef
                    }

                    $def = Copy-RWModDef @params

                    if ($def.Root.Element('statBases').Element('Beauty')) {
                        $beauty = $wood.StructuralBeauty - 1 + $def.Root.Element('statBases').Element('Beauty').Value
                        $def.Root.Element('statBases').Element('Beauty').Value = $beauty
                    } else {
                        $def.Root.Element('statBases').Add(
                            [System.Xml.Linq.XElement]::new(
                                [System.Xml.Linq.XName]'Beauty',
                                $wood.StructuralBeauty
                            )
                        )
                    }

                    $xElement = [System.Xml.Linq.XElement]::new($templateElement.ToString())
                    $xElement.Element('value').Add($def.Root)
                    $operationsElement.Add($xElement)
                }
            }
    }

    $templateElement.Remove()
    $xDocument.Save($path)
}

task CreateFloorPatches {
    foreach ($mod in $buildInfo.Data.SupportedFloorMods) {
        CreateFloorPatch -FromMod $mod
        CreateFloorPatch -FromMod $mod -TreeMod 'VGP Xtra Trees and Flowers'
    }
}

task CleanPatches {
    Get-Item (Join-Path $buildInfo.Path.GeneratedVersion 'Patches\EW-*%*') | Remove-Item
}

task UpdateVersion {
    $version = $buildInfo.Version
    $version = switch ($ReleaseType) {
        'Major' { [Version]::new($version.Major + 1, 0, 0) }
        'Minor' { [Version]::new($version.Major, $version.Minor + 1, 0) }
        'Build' { [Version]::new($version.Major, $version.Minor, $version.Build + 1) }
    }

    $path = Join-Path $psscriptroot 'source\About\Manifest.xml'
    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $xDocument.Element('Manifest').Element('version').Value = $version
    $xDocument.Save($path)
    Join-Path -Path $buildInfo.Path.Generated -ChildPath 'About' | Copy-Item $path -Destination { $_ }

    $path = Join-Path $psscriptroot 'source\About\ModSync.xml'
    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $xDocument.Descendants('Version').ForEach{ $_.Value = $version }
    $xDocument.Save($path)
    Join-Path -Path $buildInfo.Path.Generated -ChildPath 'About' | Copy-Item $path -Destination { $_ }
}

task CreatePackage {
    $params = @{
        Path            = $buildInfo.Path.Generated
        DestinationPath = Join-Path $buildInfo.Path.Build ('{0}.zip' -f $buildInfo.Name)
    }
    Compress-Archive @params
}

task UpdateLocal {
    $path = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 294100' -Name 'InstallLocation').InstallLocation
    $modPath = [System.IO.Path]::Combine($path, 'Mods', $buildInfo.Name)

    if (Test-Path $modPath) {
        Remove-Item $modPath -Recurse
    }

    Copy-Item $buildInfo.Path.Generated "$path\Mods" -Recurse -Force
}
