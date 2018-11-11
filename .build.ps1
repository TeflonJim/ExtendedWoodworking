#Requires -Module Indented.RimWorld

param (
    [ValidateSet('Major', 'Minor', 'Build')]
    [String]$ReleaseType = 'Build'
)

task Build Setup,
           Clean,
           CopyFramework,
           # GetModCheck,
           SetPublishedItemID,
           UpdateRecipeDefs,
           UpdateTerrainDefs,
           UpdateThingDefsBuildings,
           UpdateThingDefsItems,
           CreateHarvestedThingDefPatch,
           CreateCostListPatch,
           CreateWoodLogPatch,
           CreateWoodFloorPatch,
           CleanPatches,
           UpdateVersion,
           CreatePackage,
           UpdateLocal

filter ConvertTo-OrderedDictionary {
    $dictionary = [Ordered]@{}
    foreach ($name in $_.PSObject.Properties.Name) {
        $dictionary.$name = $_.$name
    }
    $dictionary
}

task Setup {
    Import-Module Indented.RimWorld -Global

    $Global:buildInfo = [PSCustomObject]@{
        Name            = 'Extended Woodworking'
        PublishedFileID = '836912371'
        Version         = $null
        Path            = [PSCustomObject]@{
            Build     = Join-Path $psscriptroot 'build'
            Generated = Join-Path $psscriptroot 'generated\Extended Woodworking'
            Source    = Join-Path $psscriptroot 'source'
        }
        Data    = [PSCustomObject]@{
            WoodPainted   = Get-Content (Join-Path $psscriptroot 'woodPainted.json') | ConvertFrom-Json | ConvertTo-OrderedDictionary
            WoodStats     = Get-Content (Join-Path $psscriptroot 'woodStats.json') | ConvertFrom-Json | ConvertTo-OrderedDictionary
            SupportedMods = @(
                'Core'
                '[RF] Fishing'
                '[RF] Fertile Fields'
                '[T] ExpandedCloth'
                '[T] MoreFloors'
                'A Dog Said... Animal Prosthetics'
                'A RimWorld of Magic'
                'Area Rugs'
                'Misc. Training'
                "Nature's Pretty Sweet"
                'RimWriter - Books, Scrolls, Tablets, and Libraries'
                'VGP Xtra Trees and Flowers'
            )
        }
    }
    $buildInfo.Version = [Version](Get-Content (Join-Path $buildInfo.Path.Source 'About\version.txt') -Raw)
}

task Clean {
    if (Test-Path $buildInfo.Path.Build) {
        Remove-Item $buildInfo.Path.Build -Recurse
    }
    if (Test-Path $buildInfo.Path.Generated) {
        Remove-Item $buildInfo.Path.Generated -Recurse
    }
    $null = New-Item $buildInfo.Path.Build -ItemType Directory
    $null = New-Item $buildInfo.Path.Generated -ItemType Directory
}

task CopyFramework {
    Copy-Item ('{0}\*' -f $buildInfo.Path.Source) $buildInfo.Path.Generated -Recurse
}

task GetModCheck {
    [Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $path = Join-Path $buildInfo.Path.Build 'ModCheck.zip'
    $destinationPath = Join-Path $buildInfo.Path.Build 'ModCheck'
    $assemblyPath = Join-Path $buildInfo.Path.Generated 'Assemblies'
    $null = New-Item $assemblyPath -ItemType Directory

    $latest = Invoke-RestMethod https://api.github.com/repos/Nightinggale/ModCheck/releases/latest
    $webRequest = Invoke-WebRequest $latest.zipball_url
    Set-Content $path -Value $webRequest.Content -Encoding Byte
    Expand-Archive $path -DestinationPath (Join-Path $buildInfo.Path.Build 'ModCheck')
    Get-ChildItem $destinationPath -Filter *.dll -Recurse | Copy-Item -Destination $assemblyPath

    Remove-Item $path, $destinationPath -Recurse
}

task SetPublishedItemID {
    Set-Content (Join-Path $buildInfo.Path.Generated 'About\PublishedFileId.txt') -Value $buildInfo.PublishedFileID
}

task UpdateRecipeDefs {
    $path = Join-Path $buildInfo.Path.Generated 'Defs\RecipeDefs\EW-Woodworking.xml'

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
    $params = @{
        Name    = 'Core\FloorBase'
        SaveAs  = Join-Path $buildInfo.Path.Generated 'Defs\TerrainDefs\EW-Base.xml'
    }
    Copy-RWModDef @params

    # Floors (natural)

    $path = Join-Path $buildInfo.Path.Generated 'Defs\TerrainDefs\EW-WoodFloors.xml'

    $commonParams = @{
        Name    = 'Core\WoodPlankFloor'
        SaveAs  = $path
        Remove  = 'costList', 'designationHotKey'
    }
    foreach ($woodType in $buildInfo.Data.WoodStats.Keys) {
        if ($buildInfo.Data.WoodStats[$woodType].Mod) {
            continue
        }

        $params = @{
            NewName = 'WoodPlankFloor_{0}' -f $woodType
            Update  = @{
                label                                 = '{0} wood floor' -f $woodType.ToLower()
                description                           = '{0} plank flooring. For that warm, homey feeling.' -f $woodType
                color                                 = $buildInfo.Data.WoodStats[$woodType].Colour
                ('costList.WoodLog_{0}' -f $woodType) = 6
                'statBases.Beauty'                    = $buildInfo.Data.WoodStats[$woodType].StructuralBeauty
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
    }
    foreach ($colour in $buildInfo.Data.WoodPainted.Keys) {
        $params = @{
            NewName = 'WoodPlankFloor_{0}' -f $colour
            Update  = @{
                label                               = '{0} painted wood floor' -f $colour.ToLower()
                description                         = '{0} wood plank flooring. For that warm, homey feeling.' -f $colour
                color                               = $buildInfo.Data.WoodPainted[$colour]
                ('costList.WoodLog_{0}' -f $colour) = 6
                "statBases.Beauty"                  = 2
                texturePath                         = 'Floor/WoodFloorBase'
            }
        }
        Copy-RWModDef @commonParams @params
    }
}

task UpdateThingDefsBuildings {
    $path = Join-Path $buildInfo.Path.Generated 'Defs\ThingDefs_Buildings\EW-Base.xml'

    $commonParams = @{
        Name    = 'Core\BuildingBase'
        SaveAs  = $path
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
    }
    Copy-RWModDef @params
}

task UpdateThingDefsItems {
    $commonParams = @{
        SaveAs  = Join-Path $buildInfo.Path.Generated 'Defs\ThingDefs_Items\EW-Base.xml'
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
        SaveAs  = Join-Path $buildInfo.Path.Generated 'Defs\ThingDefs_Items\EW-WoodTypes.xml'
    }

    # WoodLog (generic)

    Copy-RWModDef @commonParams -Update @{
        label           = 'generic wood'
        description     = "The most generic piece of wood you've ever seen. So generic you can't even tell what kind of wood it is."
        thingCategories = @('WoodTypes')
    }

    # Woodlog (natural)

    foreach ($woodType in $buildInfo.Data.WoodStats.Keys) {
        if ($buildInfo.Data.WoodStats[$woodType].Mod) {
            continue
        }

        $params = @{
            NewName = 'WoodLog_{0}' -f $woodType
            Update  = @{
                label                                  = '{0} wood' -f $woodType
                'graphicData.texPath'                  = 'Logs/WoodLog'
                'graphicData.graphicClass'             = 'Graphic_Single'
                'graphicData.color'                    = $buildInfo.Data.WoodStats[$woodType].Colour
                'stuffProps.color'                     = $buildInfo.Data.WoodStats[$woodType].Colour
                'stuffProps.statFactors.MaxHitPoints'  = $buildInfo.Data.WoodStats[$woodType].MaxHitPoints
                'stuffProps.statFactors.Beauty'        = $buildInfo.Data.WoodStats[$woodType].StructuralBeauty
                'stuffProps.statFactors.WorkToMake'    = $buildInfo.Data.WoodStats[$woodType].WorkToMake
                'stuffProps.statFactors.DoorOpenSpeed' = $buildInfo.Data.WoodStats[$woodType].DoorOpenSpeed
                'stuffProps.stuffAdjective'            = $woodType.ToLower()
                thingCategories                        = @('WoodTypes')
            }
        }
        Copy-RWModDef @commonParams @params
    }

    # WoodLog (painted)

    $commonParams = @{
        Name    = 'Core\WoodLog'
        SaveAs  = Join-Path $buildInfo.Path.Generated 'Defs\ThingDefs_Items\EW-PaintedWood.xml'
    }

    foreach ($colour in $buildInfo.Data.WoodPainted.Keys) {
        $params = @{
            NewName = 'WoodLog_{0}' -f $colour
            Update  = @{
                ParentName                  = 'ResourceBasePainted'
                label                       = '{0} painted wood' -f $colour
                description                 = 'Wood that has been painted {0}' -f $colour.ToLower()
                'graphicData.color'         = $buildInfo.Data.WoodPainted[$colour]
                'stuffProps.color'          = $buildInfo.Data.WoodPainted[$colour]
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
        if ($modInfo) {
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
                    BaseName = $item.BaseName -replace '[^A-Za-z0-9]'
                    Path     = $item.FullName
                    Node     = $_
                }
            } | Group-Object Path | ForEach-Object {
                $newName = 'Patches/EW-%MOD%-%GROUP%-costList.xml' -replace '%MOD%', $shortName -replace '%GROUP%', $_.Group[0].BaseName
                $newPath = Join-Path $buildInfo.Path.Generated $newName
                $template = Join-Path $buildInfo.Path.Source 'Patches/EW-%MOD%-%GROUP%-costList.xml'

                Copy-Item $template $newPath -Force

                $xDocument = [System.Xml.Linq.XDocument]::Load($newPath)
                $xDocument.Descendants('mods').ForEach{ $_.Element('li').Value = (Get-RWMod -Name $mod).RawName }

                $template = [System.Xml.XPath.Extensions]::XPathSelectElements(
                    $xDocument,
                    '//operations/li[not(contains(@Class, "ModCheck"))]'
                ) | ForEach-Object { $_ }

                foreach ($item in $_.Group) {
                    foreach ($templateItem in $template) {
                        $xmlString = $templateItem.ToString() -replace '%NAME%', $item.Node.Element('defName').Value
                        $xmlString = $xmlString -replace '%COST%', $item.Node.Element('costList').Element('WoodLog').Value

                        $xElement = [System.Xml.Linq.XElement]::new($xmlString)
                        $xDocument.Descendants('operations')[0].Add($xElement)
                    }
                }

                $template.ForEach{ $_.Remove() }

                $xDocument.Save($newPath)
            }
        }
    }
}

task CreateHarvestedThingDefPatch {
    foreach ($mod in $buildInfo.Data.SupportedMods) {
        $modInfo = Get-RWMod $mod
        if ($modInfo) {
            $shortName = $mod -replace '[^A-Za-z0-9]'

            Get-ChildItem (Join-Path $modInfo.Path 'Defs') -Filter *.xml -Recurse | ForEach-Object {
                $item = $_

                $xDocument = [System.Xml.Linq.XDocument]::Load($item.FullName)
                $xDocument.Descendants('defName').Where{
                    $_.Value -match 'Plant_Tree' -and
                    $buildInfo.Data.woodStats.Contains($_.Value -replace 'Plant_Tree')
                }.ForEach{
                    [PSCustomObject]@{
                        BaseName = $item.BaseName -replace '[^A-Za-z0-9]'
                        Path     = $item.FullName
                        Name     = $_.Value -replace 'Plant_Tree'
                    }
                }
            } | Group-Object Path | ForEach-Object {
                $newName = 'Patches/EW-%MOD%-%GROUP%-harvestedThingDef.xml' -replace '%MOD%', $shortName -replace '%GROUP%', $_.Group[0].BaseName
                $newPath = Join-Path $buildInfo.Path.Generated $newName
                $template = Join-Path $buildInfo.Path.Source 'Patches/EW-%MOD%-%GROUP%-harvestedThingDef.xml'

                Copy-Item $template $newPath -Force

                $xDocument = [System.Xml.Linq.XDocument]::Load($newPath)
                $xDocument.Descendants('mods').ForEach{ $_.Element('li').Value = (Get-RWMod -Name $mod).RawName }

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
}

task CreateWoodLogPatch {
    $commonParams = @{
        Name    = 'Core\WoodLog'
    }

    $templatePath = Join-Path $buildInfo.Path.Generated 'Patches\EW-%MOD%-woodLog.xml'
    $buildInfo.Data.WoodStats.Keys | Where-Object { $buildInfo.Data.WoodStats[$_].Mod } | ForEach-Object {
        [PSCustomObject]@{
            Mod  = $buildInfo.Data.WoodStats[$_].Mod
            Name = $_
        }
    } | Group-Object Mod | ForEach-Object {
        $mod = $_.Name
        $shortName = $mod -replace '[^A-Za-z0-9]'

        $path = Join-Path $buildInfo.Path.Generated ('Patches\EW-{0}-woodLog.xml' -f $shortName)
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
    }

    $templatePath = Join-Path $buildInfo.Path.Generated 'Patches\EW-%MOD%-woodFloor.xml'
    $buildInfo.Data.WoodStats.Keys | Where-Object { $buildInfo.Data.WoodStats[$_].Mod } | ForEach-Object {
        [PSCustomObject]@{
            Mod  = $buildInfo.Data.WoodStats[$_].Mod
            Name = $_
        }
    } | Group-Object Mod | ForEach-Object {
        $mod = $_.Name
        $shortName = $mod -replace '[^A-Za-z0-9]'

        $path = Join-Path $buildInfo.Path.Generated ('Patches\EW-{0}-woodFloor.xml' -f $shortName)
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
                NewName = 'WoodPlankFloor_{0}' -f $item
                Update  = @{
                    label                             = '{0} wood floor' -f $item.ToLower()
                    description                       = '{0} plank flooring. For that warm, homey feeling.' -f $item
                    color                             = $buildInfo.Data.WoodStats[$item].Colour
                    ('costList.WoodLog_{0}' -f $item) = 6
                    'statBases.Beauty'                = $buildInfo.Data.WoodStats[$item].StructuralBeauty
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

task CleanPatches {
    Get-Item (Join-Path $buildInfo.Path.Generated 'Patches\EW-*%*') | Remove-Item
}

task UpdateVersion {
    $version = $buildInfo.Version
    $version = switch ($ReleaseType) {
        'Major' { [Version]::new($version.Major + 1, 0, 0) }
        'Minor' { [Version]::new($version.Major, $version.Minor + 1, 0) }
        'Build' { [Version]::new($version.Major, $version.Minor, $version.Build + 1) }
    }
    Set-Content "$psscriptroot\source\About\version.txt" -Value $version.ToString()

    $xDocument = [System.Xml.Linq.XDocument]::Load("$psscriptroot\source\About\ModSync.xml")
    $xDocument.Descendants('Version').ForEach{ $_.Value = $version }
    $xDocument.Save("$psscriptroot\source\About\ModSync.xml")

    Copy-Item "$psscriptroot\source\About\version.txt" (Join-Path $buildInfo.Path.Generated 'About')
    Copy-Item "$psscriptroot\source\About\ModSync.xml" (Join-Path $buildInfo.Path.Generated 'About')
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