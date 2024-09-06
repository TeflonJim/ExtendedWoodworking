#Requires -Module Indented.RimWorld -PSEdition Core

using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Text
using namespace System.Xml.Linq


[CmdletBinding()]
param (
    [ValidateSet('Major', 'Minor', 'Build')]
    [string]
    $ReleaseType = 'Build',

    [string[]]
    $TaskName = @(
        'Setup'
        'UpdateLastVersion'
        'Clean'
        'Discovery'
        'CopyFramework'
        'SetPublishedItemID'
        'CreateWoodLogDef'
        'CreatePaintedWoodLogDef'
        'CreateModFuelPatch'
        'CreatePaintedWoodRecipeDef'
        'CreateCostListPatch'
        'CreateRecipePatch'
        'CreateHarvestedThingPatch'
        'CreateDesignatorGroupDef'
        'CreateDesignatorGroupPatch'
        'CreateTerrainDef'
        'CreateTerrainPatch'
        'CreatePaintedTerrainDef'
        'UpdateCherryPicker'
        'UpdateLoadFolders'
        'UpdateMetadata'
        'CreatePackage'
        'UpdateLocal'
    )
)

class BuildInfo {
    [string] $Name = 'Extended Woodworking'
    [string] $PublishedFileID = '836912371'
    [object] $RimWorldVersion = (Get-RWVersion)
    [Version] $Version
    [PathInfo] $Path
    [ModBuildData] $Data

    BuildInfo([string] $path) {
        $manifestPath = Join-Path $path 'source\About\Manifest.xml'
        $xDocument = [XDocument]::Load($manifestPath)
        $this.Version = [Version]$xDocument.Element('Manifest').Element('version').Value
        $this.Path = [PathInfo]::new($path, $this.RimWorldVersion.ShortVersion)

        $this.Data = Join-Path -Path $path -ChildPath 'modBuildData.json' |
            Get-Content -LiteralPath { $_ } -Raw |
            ConvertFrom-Json

        $this.Data._version = $this.RimWorldVersion.ShortVersion
        $this.Data.Init()
    }
}

class PathInfo {
    [string] $Build
    [string] $Source
    [string] $About
    [string] $LoadFolders
    [string] $Archive
    [string] $Template
    [string] $Generated
    [string] $GeneratedVersioned
    [string] $GeneratedConditionalVersioned
    [string] $Painted

    PathInfo([string] $path, [string] $version) {
        $this.Build = [Path]::Combine($path, 'build')
        $this.Source = [Path]::Combine($path, 'source')
        $this.About = [Path]::Combine($this.Source, 'About\About.xml')
        $this.LoadFolders = [Path]::Combine($this.Source, 'LoadFolders.xml')
        $this.Archive = [Path]::Combine($path, 'archive')
        $this.Template = [Path]::Combine($this.Source, 'template')

        $this.Generated = [Path]::Combine($path, 'generated\Extended Woodworking')
        $this.GeneratedVersioned = [Path]::Combine($this.Generated, $version)
        $this.GeneratedConditionalVersioned = [Path]::Combine($this.Generated, 'Conditional', $version)
        $this.Painted = [Path]::Combine($this.GeneratedConditionalVersioned, '_EW-Painted')
    }
}

class ModBuildData {
    hidden [Version] $_version

    <#
        Names and colours of painted woods.
    #>
    [WoodPaint[]] $WoodPainted

    <#
        Names, colours, beauty, and strength of harvested woods.
    #>
    [WoodStat[]] $WoodStats

    <#
        Mods which will be ignored when discovering defs requiring explicit targetted patching.

        Does not affect fuel patching so it does not represent an incompatibility, only an inability to meaningfully
        perform specific patching.
    #>
    [string[]] $IgnoreMods

    <#
        Discovered patch definitions.
    #>
    [PatchGeneratorInfo] $DiscoveredDefs = [PatchGeneratorInfo]::new()

    <#
        Defs which should be excluded because they are not compatible, or something goes wrong attempting to patch.
    #>
    [string[]] $ExcludedDefs

    <#
        A regex generated from ExcludedDefs.
    #>
    [string] $ExcludedDefsPattern

    <#
        Additional mods to add to the LoadAfter list where content is not automatically discovered.
    #>
    [string[]] $LoadAfter

    <#
        Mods that are explicitly supported because patches have been generated.
    #>
    [Dictionary[string,object]] $SupportedMods = [Dictionary[string,object]]::new()

    <#
        Mods that implement floors.
    #>
    [List[object]] $SupportedFloorMods = [List[object]]::new()

    <#
        Load folders entries.
    #>
    [SortedSet[LoadFoldersEntry]] $LoadFolders

    <#
        A helper used to record values which will be added to LoadFolders.
    #>
    [void] AddLoadFoldersEntry([string] $path) {
        $this.AddLoadFoldersEntry($path, @())
    }

    [void] AddLoadFoldersEntry([string] $path, [string[]] $ifModActive) {
        $entry = [LoadFoldersEntry]@{
            Path        = 'Conditional/{0}/{1}' -f $this._version, $path
            IfModActive = $ifModActive
        }
        $this.LoadFolders.Add($entry)
    }

    [void] Init() {
        $this.ExcludedDefsPattern = '^({0})$' -f ($this.ExcludedDefs -join '|')

        $this.InitCache()
        $this.InitLoadFolders()
    }

    [void] InitCache() {
        foreach ($item in $this.WoodPainted) {
            [WoodPaint]::Add($item)
        }
        foreach ($item in $this.WoodStats) {
            [WoodStat]::Add($item)
        }
        [WoodStat]::InitMatcher()
    }

    [void] InitLoadFolders() {
        $this.LoadFolders = @(
            [LoadFoldersEntry]@{ Path = '/' }
            [LoadFoldersEntry]@{ Path = $this._version }
        )
    }
}

class PatchGeneratorInfo {
    [Dictionary[string,object]] $CostList = [Dictionary[string,object]]::new()
    [Dictionary[string,object]] $Recipe = [Dictionary[string,object]]::new()
    [Dictionary[string,object]] $HarvestedThing = [Dictionary[string,object]]::new()
    [Dictionary[string,object]] $Terrain = [Dictionary[string,object]]::new()
}

class WoodPaint {
    hidden static [Dictionary[string,WoodPaint]] $_lookup = [Dictionary[string,WoodPaint]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    [string] $Name
    [string] $Colour

    static [void] Add(
        [WoodPaint] $item
    ) {
        [WoodPaint]::_lookup[$item.Name] = $item
    }

    static [WoodPaint] Get(
        [string] $Name
    ) {
        $value = $null
        if ([WoodPaint]::_lookup.TryGetValue($Name, [ref]$value)) {
            return $value
        }
        return $null
    }
}

class WoodStat {
    hidden static [string] $_pattern
    hidden static [string] $_aliases

    hidden static [Dictionary[string,WoodStat]] $_lookup = [Dictionary[string,WoodPaint]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    hidden static [Dictionary[string,string]] $_aliasesLookup = [Dictionary[string,WoodPaint]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    [string] $Name
    [string] $DescriptiveName
    [string[]] $Aliases
    [decimal] $MaxHitPoints
    [decimal] $StructuralBeauty
    [decimal] $WorkToMake
    [decimal] $DoorOpenSpeed
    [string] $Colour
    [SortedSet[string]] $ImplementingMod = [SortedSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    static InitMatcher() {
        [WoodStat]::_pattern = [WoodStat]::_lookup.Keys -join '|'
        [WoodStat]::_aliases = [WoodStat]::_aliasesLookup.Keys -join '|'
    }

    static [void] Add(
        [WoodStat] $item
    ) {
        [WoodStat]::_lookup[$item.Name] = $item

        if ($item.Aliases) {
            foreach ($alias in $item.Aliases) {
                if ([WoodStat]::_lookup.ContainsKey($alias)) {
                    throw 'Invalid data, wood alias {0} overlaps with wood type name.' -f $alias
                }
                [WoodStat]::_aliasesLookup[$alias] = $item.Name
            }
        }
    }

    static [string] GetWoodType([string] $defName, [string] $packageID) {
        if ($defName -match [WoodStat]::_pattern) {
            [WoodStat]::Get($matches[0]).ImplementingMod.Add($packageID)

            return $matches[0]
        }
        if ($defName -match [WoodStat]::_aliases) {
            return [WoodStat]::GetWoodType([WoodStat]::_aliasesLookup[$matches[0]], $packageID)
        }
        return $null
    }

    static [WoodStat] Get(
        [string] $Name
    ) {
        $value = $null
        if ([WoodStat]::_lookup.TryGetValue($Name, [ref]$value)) {
            return $value
        }

        return $null
    }
}

class LoadFoldersEntry : IComparable, IEquatable[object] {
    [string] $Path
    [string[]] $IfModActive

    [XElement] ToXElement() {
        $children = @(
            $this.Path
        )
        if ($this.IfModActive) {
            $children += [XAttribute]::new([XName]'IfModActive', ($this.IfModActive -join ','))
        }

        return [XElement]::new([XName]'li', $children)
    }

    [int] CompareTo([object] $other) {
        return [string]::Compare($this.Path, $other.Path, $true)
    }

    [bool] Equals([object] $other) {
        return $this.Path -eq $other.Path
    }
}

function Confirm-ParentDirectory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $parent = [Path]::GetDirectoryName($Path)
    if (-not (Test-Path $parent)) {
        $null = New-Item -Path $parent -ItemType Directory
    }
}

function Setup {
    $Script:buildInfo = [BuildInfo]::new($PSScriptRoot)
}

function UpdateLastVersion {
    $aboutXml = [XDocument]::Load($buildInfo.Path.About)
    $supportedVersionsNode = $aboutXml.Element('ModMetaData').Element('supportedVersions')

    $supportedVersions = $supportedVersionsNode.Elements('li').Value -as [Version[]] | Sort-Object

    $version = $buildInfo.RimWorldVersion.ShortVersion
    if ($version -notin $supportedVersions) {
        $lastVersion = $supportedVersions[-1]
        
        $path = [Path]::Combine($buildInfo.Path.Archive, $lastVersion)

        if (-not (Test-Path $path)) {
            $contentToArchive = [Path]::Combine($buildInfo.Path.Generated, $lastVersion)

            if (Test-Path $contentToArchive) {
                Copy-Item -Path $contentToArchive -Destination $buildInfo.Path.Archive -Recurse -Force
            }
        }

        $path = [Path]::Combine($buildInfo.Path.Archive, 'Conditional', $lastVersion)

        if (-not (Test-Path $path)) {
            $contentToArchive = [Path]::Combine($buildInfo.Path.Generated, 'Conditional', $lastVersion)

            if (Test-Path $contentToArchive) {
                Copy-Item -Path $contentToArchive -Destination ([Path]::Combine($buildInfo.Path.Archive, 'Conditional')) -Recurse -Force
            }
        }

        $supportedVersionsNode.Add([XElement]::new([XName]'li', $version))

        $aboutXml.Save($buildInfo.Path.About)
    }
}

function Clean {
    if (Test-Path $buildInfo.Path.Build) {
        Remove-Item $buildInfo.Path.Build -Recurse
    }
    if (Test-Path $buildInfo.Path.Generated) {
        Remove-Item $buildInfo.Path.Generated -Recurse
    }
    New-Item $buildInfo.Path.Build -ItemType Directory
    New-Item $buildInfo.Path.GeneratedVersioned -ItemType Directory
    New-Item $buildInfo.Path.GeneratedConditionalVersioned -ItemType Directory
}

function Discovery {
    foreach ($modInfo in Get-RWMod) {
        if ($modInfo.PackageID -in $buildInfo.Data.IgnoreMods) {
            continue
        }

        $verbose = @('{0} ({1}):' -f $modInfo.Name.Trim(), $modInfo.PackageID)

        # CostList
        $discoveredDefs = $modInfo | Get-RWModDef -Version $buildInfo.RimWorldVersion.ShortVersion -XPathQuery (
            '/Defs/*[name()!="TerrainDef" and defName and not(stuffCategories) and ./costList/WoodLog]'
        ) | Where-Object DefName -notmatch $buildInfo.Data.ExcludedDefsPattern

        if ($discoveredDefs) {
            $verbose += '    CostList: Patching {0} defs' -f $discoveredDefs.Count

            $buildInfo.Data.DiscoveredDefs.CostList[$modInfo.PackageID] = $discoveredDefs
            $buildInfo.Data.SupportedMods[$modInfo.Name] = $modInfo
        }

        # Recipe
        $discoveredDefs = $modInfo | Get-RWModDef -Version $buildInfo.RimWorldVersion.ShortVersion -XPathQuery (
            '/Defs/RecipeDef[(@Abstract="False" or not(@Abstract)) and (ingredients/li/filter/thingDefs/li="WoodLog" or fixedIngredientFilter/thingDefs/li="WoodLog")]'
        ) | Where-Object DefName -notmatch $buildInfo.Data.ExcludedDefsPattern

        if ($discoveredDefs) {
            $verbose += '    Recipe: Patching {0} defs' -f $discoveredDefs.Count

            $buildInfo.Data.DiscoveredDefs.Recipe[$modInfo.PackageID] = $discoveredDefs
            $buildInfo.Data.SupportedMods[$modInfo.Name] = $modInfo
        }

        # HarvestedThing
        $discoveredDefs = $modInfo | Get-RWModDef -Version $buildInfo.RimWorldVersion.ShortVersion -XPathQuery (
            '/Defs/ThingDef[(@Abstract="False" or not(@Abstract)) and contains(@ParentName, "TreeBase") and not(plant/harvestedThingDef)]'
        )  | Where-Object DefName -notmatch $buildInfo.Data.ExcludedDefsPattern | ForEach-Object {
            [PSCustomObject]@{
                DefName  = $_.DefName
                WoodType = [WoodStat]::GetWoodType($_.DefName, $modInfo.PackageID)
            }
        } | Where-Object WoodType

        if ($discoveredDefs) {
            $verbose += '    HarvestedThing: Patching {0} defs' -f $discoveredDefs.Count

            $buildInfo.Data.DiscoveredDefs.HarvestedThing[$modInfo.PackageID] = $discoveredDefs
            $buildInfo.Data.SupportedMods[$modInfo.Name] = $modInfo
        }

        # Wood floor
        $discoveredDefs = $modInfo | Get-RWModDef -Version $buildInfo.RimWorldVersion.ShortVersion -XPathQuery (
            '/Defs/TerrainDef[costList/WoodLog and description and not(designatorDropdown)]'
        ) | Where-Object DefName -notmatch $buildInfo.Data.ExcludedDefsPattern
        if ($discoveredDefs) {
            $verbose += '    Terrain: Patching {0} defs' -f $discoveredDefs.Count

            $buildInfo.Data.DiscoveredDefs.Terrain[$modInfo.PackageID] = $discoveredDefs
            $buildInfo.Data.SupportedFloorMods.Add($modInfo)
        }

        if ($verbose.Count -gt 1) {
            $verbose | Write-Verbose -Verbose
        }
    }
}

function CopyFramework {
    Get-ChildItem -Path $buildInfo.Path.Archive | Copy-Item -Destination $buildInfo.Path.Generated -Recurse
    Get-ChildItem -Path $buildInfo.Path.Source -Exclude template, conditional_template | Copy-Item -Destination $buildInfo.Path.Generated -Recurse
    [Path]::Combine($buildInfo.Path.Source, 'template\*') | Copy-Item -Destination $buildInfo.Path.GeneratedVersioned -Recurse
    [Path]::Combine($buildInfo.Path.Source, 'conditional_template\*') | Copy-Item -Destination $buildInfo.Path.GeneratedConditionalVersioned -Recurse
}

function SetPublishedItemID {
    Set-Content (Join-Path $buildInfo.Path.Generated 'About\PublishedFileId.txt') -Value $buildInfo.PublishedFileID
}

function CreateWoodLogDef {
    $commonParams = @{
        SaveAs  = [Path]::Combine($buildInfo.Path.GeneratedVersioned, 'Defs\ThingDefs_Items\EW-WoodLog.xml')
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }
    Copy-RWModDef @commonParams -Name 'Core\ResourceBase'
    Copy-RWModDef @commonParams -Name 'Core\ResourceVerbBase'

    $commonParams['Name'] = 'Core\WoodLog'

    Copy-RWModDef @commonParams -Update @{
        label           = 'generic wood'
        description     = "The most generic piece of wood you've ever seen. So generic you can't even tell what kind of wood it is."
        thingCategories = @('WoodTypes')
    }

    foreach ($wood in $buildInfo.Data.WoodStats) {
        if ($wood.ImplementingMod -contains 'ludeon.rimworld') {
            $commonParams['SaveAs'] = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Defs\ThingDefs_Items\EW-WoodLog.xml'
            )
        } else {
            $commonParams['SaveAs'] = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                '_EW-WoodLog_{0}' -f $wood.Name,
                'Defs\ThingDefs_Items',
                'EW-WoodLog.{0}.xml' -f $wood.Name
            )

            Confirm-ParentDirectory $commonParams['SaveAs']

            [Path]::Combine($buildInfo.Path.Template, 'Defs\ThingDefs_Items\EW-WoodLog.xml') |
                Copy-Item -Destination $commonParams['SaveAs']

            $buildInfo.Data.AddLoadFoldersEntry('_EW-WoodLog_{0}' -f $wood.Name, $wood.ImplementingMod)
        }

        $params = @{
            NewName = 'WoodLog_{0}' -f $wood.Name
            Update  = @{
                label                                  = '{0} wood' -f $wood.Name
                'graphicData.texPath'                  = 'Logs/WoodLog'
                'graphicData.graphicClass'             = 'Graphic_Single'
                'graphicData.color'                    = $wood.Colour
                'stuffProps.color'                     = $wood.Colour
                'stuffProps.statFactors.MaxHitPoints'  = $wood.MaxHitPoints
                'stuffProps.statFactors.Beauty'        = $wood.StructuralBeauty
                'stuffProps.statFactors.WorkToMake'    = $wood.WorkToMake
                'stuffProps.statFactors.DoorOpenSpeed' = $wood.DoorOpenSpeed
                'stuffProps.stuffAdjective'            = $wood.Name.ToLower()
                thingCategories                        = @('WoodTypes')
            }
        }
        Copy-RWModDef -Name 'Core\WoodLog' @commonParams @params
    }
}

function CreatePaintedWoodLogDef {
    $commonParams = @{
        SaveAs  = [Path]::Combine(
            $buildInfo.Path.Painted,
            'Defs\ThingDefs_Items\EW-WoodLog-Painted.xml'
        )
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }
    
    Confirm-ParentDirectory $commonParams['SaveAs']

    $params = @{
        Name    = 'Core\ResourceBase'
        NewName = 'ResourceBasePainted'
        Update  = @{
            'graphicData.texPath'      = 'Logs/WoodLog'
            'graphicData.graphicClass' = 'Graphic_Single'
        }
    }
    Copy-RWModDef @commonParams @params

    foreach ($wood in $buildInfo.Data.WoodPainted) {
        $params = @{
            NewName = 'WoodLog_{0}' -f $wood.Name
            Update  = @{
                ParentName                  = 'ResourceBasePainted'
                label                       = '{0} painted wood' -f $wood.Name
                description                 = 'Wood that has been painted {0}' -f $wood.Name.ToLower()
                'graphicData.color'         = $wood.Colour
                'stuffProps.color'          = $wood.Colour
                'stuffProps.stuffAdjective' = $wood.Name.ToLower()
                thingCategories             = @('WoodTypes')
            }
        }
        Copy-RWModDef -Name 'Core\WoodLog' @commonParams @params
    }

    $buildInfo.Data.AddLoadFoldersEntry('_EW-Painted')
}

function CreateModFuelPatch {
    $templatePath = [Path]::Combine($buildInfo.Path.Template, 'Patches\EW-FuelFilter.xml')

    foreach ($wood in $buildInfo.Data.WoodStats) {
        if ($wood.ImplementingMod -contains 'ludeon.rimworld') {
            continue
        }

        $path = [Path]::Combine(
            $buildInfo.Path.GeneratedConditionalVersioned,
            '_EW-WoodLog_{0}' -f $wood.Name,
            'Patches',
            'EW-FuelFilter.{0}.xml' -f $wood.Name
        )

        Confirm-ParentDirectory $path

        Copy-Item -Path $templatePath -Destination $path
    
        $xDocument = [XDocument]::Load($path)
        $filterValue = $xDocument.Root.Element('Operation').Element('value')
        $filterValue.ReplaceAll([XElement]::new([XName]'li', 'WoodLog_{0}' -f $wood.Name))

        $xDocument.Save($path)
    }
}

function CreatePaintedWoodRecipeDef {
    $path = [Path]::Combine(
        $buildInfo.Path.Painted,
        'Defs\RecipeDefs\EW-Woodworking-Painted.xml'
    )
    Confirm-ParentDirectory $path

    $xDocument = [XDocument]::Load($path)
    $template = $xDocument.Root.Elements('RecipeDef').Where( { $_.Element('defName').Value -eq 'PaintWoodLogTemplate' } )[0]

    foreach ($item in $buildInfo.Data.WoodPainted) {
        $colour = $item.Name
        $recipe = [XElement]::new($template)

        $recipe.Element('defName').SetValue("PaintWoodLog_$colour")
        $recipe.Element('label').SetValue(('paint wood {0}' -f $colour.ToLower()))
        $recipe.Element('description').SetValue(('Paints wood {0}' -f $colour.ToLower()))
        $recipe.Element('products').Add(
            [XElement]::new([XName]"WoodLog_$colour", 25)
        )
        $recipe.Element('defaultIngredientFilter').
            Element('disallowedThingDefs').
            Add([XElement]::new([XName]'li', "WoodLog_$colour"))

        $xDocument.Root.Add($recipe)
    }

    # Remove the template
    $template.Remove()
    $xDocument.Save($path)
}

function CreateCostListPatch {
    $templatePath = [Path]::Combine($buildInfo.Path.Template, 'Patches\EW-CostList.xml')

    foreach ($packageID in $buildInfo.Data.DiscoveredDefs.CostList.Keys) {
        if ($packageID -eq 'ludeon.rimworld') {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Patches/EW-CostList.xml'
            )
        } else {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                $packageID,
                'Patches/EW-CostList.{0}.xml' -f $packageID
            )

            $buildInfo.Data.AddLoadFoldersEntry($packageID, $packageID)
        }

        Confirm-ParentDirectory $path
        Copy-Item -Path $templatePath -Destination $path

        $xDocument = [XDocument]::Load($path)
        $parent = $xDocument.Root.Element('Operation').Element('operations')
        $template = [XElement[]]$parent.Elements()

        foreach ($item in $buildInfo.Data.DiscoveredDefs.CostList[$packageID]) {
            foreach ($templateItem in $template) {
                $xmlString = $templateItem.ToString() -replace '%NAME%', $item.XElement.Element('defName').Value
                $xmlString = $xmlString -replace '%COST%', $item.XElement.Element('costList').Element('WoodLog').Value

                $xElement = [XElement]::new($xmlString)

                $parent.Add($xElement)
            }
        }

        $template.ForEach{
            $_.Remove()
        }

        $xDocument.Save($path)
    }
}

function CreateRecipePatch {
    $templatePath = [Path]::Combine($buildInfo.Path.Template, 'Patches\EW-Recipe.xml')

    foreach ($packageID in $buildInfo.Data.DiscoveredDefs.Recipe.Keys) {
        if ($packageID -eq 'ludeon.rimworld') {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Patches/EW-Recipe.xml'
            )
        } else {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                $packageID,
                'Patches/EW-Recipe.{0}.xml' -f $packageID
            )

            $buildInfo.Data.AddLoadFoldersEntry($packageID, $packageID)
        }

        Confirm-ParentDirectory $path
        Copy-Item $templatePath -Destination $path -Force

        $xDocument = [XDocument]::Load($path)

        $parent = $xDocument.Root.Element('Operation').Element('operations')
        $template = [XElement[]]$parent.Elements()

        foreach ($item in $buildInfo.Data.DiscoveredDefs.Recipe[$packageID]) {
            if ($element = $item.XElement.Element('defName')) {
                $defName = $element.Value
            } elseif ($attribute = $item.XElement.Attribute('Name')) {
                $defName = $attribute.Value
            }

            foreach ($templateItem in $template) {
                $xmlString = $templateItem.ToString() -replace '%NAME%', $defName
                $count = [System.Xml.XPath.Extensions]::XPathSelectElements(
                    $item.XElement,
                    'ingredients/li[filter/thingDefs/li="WoodLog"]/count'
                ).Value
                $xmlString = $xmlString -replace '%COUNT%', $count

                $xElement = [XElement]::new($xmlString)

                $parent.Add($xElement)
            }
        }

        $template.ForEach{ $_.Remove() }

        $xDocument.Save($path)
    }
}

function CreateHarvestedThingPatch {
    $templatePath = [Path]::Combine($buildInfo.Path.Template, 'Patches\EW-HarvestedThing.xml')

    foreach ($packageID in $buildInfo.Data.DiscoveredDefs.HarvestedThing.Keys) {
        if ($packageID -eq 'ludeon.rimworld') {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Patches/EW-HarvestedThing.xml'
            )
        } else {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                $packageID,
                'Patches/EW-HarvestedThing.{0}.xml' -f $packageID
            )

            $buildInfo.Data.AddLoadFoldersEntry($packageID, $packageID)
        }

        Confirm-ParentDirectory $path
        Copy-Item $templatePath -Destination $path -Force

        $xDocument = [XDocument]::Load($path)
        $parent = $xDocument.Root.Element('Operation').Element('operations')
        $template = $parent.Element('li')

        foreach ($item in $buildInfo.Data.DiscoveredDefs.HarvestedThing[$packageID]) {
            $xmlString = $template.ToString() -replace '%NAME%', $item.DefName -replace '%TYPE%', $item.WoodType

            $xElement = [XElement]::new($xmlString)
            $parent.Add($xElement)
        }

        $template.Remove()
        $xDocument.Save($path)
    }
}

<#
    Terrain patching is easily the most complicated part of this generator so it gets saved until last.
#>

function CreateDesignatorGroupDef {
    # A new designator group is added for each patched terrain def.

    foreach ($packageID in $buildInfo.Data.DiscoveredDefs.Terrain.Keys) {
        if ($packageID -eq 'ludeon.rimworld') {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Defs\DesignatorDropdownDefs\EW-DesignatorDropdown.xml'
            )
        } else {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                $packageID,
                'Defs\DesignatorDropdownDefs\EW-DesignatorDropdown.{0}.xml' -f $packageID
            )

            $buildInfo.Data.AddLoadFoldersEntry($packageID, $packageID)
        }

        Confirm-ParentDirectory $path
        [Path]::Combine($buildInfo.Path.Template, 'Defs\DesignatorDropdownDefs\EW-DesignatorDropdown.xml') |
            Copy-Item -Destination $path

        $xDocument = [XDocument]::Load($path)
        foreach ($def in $buildInfo.Data.DiscoveredDefs.Terrain[$packageID]) {
            $designatorName = 'EW_Designator_{0}' -f $def.DefName
           
            $xDocument.Root.Add(
                [XElement]::new(
                    [XName]'DesignatorDropdownGroupDef',
                    [XElement]::new([XName]'defName', $designatorName)
                )
            )
        }
        $xDocument.Save($path)
    }
}

function CreateDesignatorGroupPatch {
    # In addition to creating designators for new defs, the original def needs patching with the designator group.

    foreach ($packageID in $buildInfo.Data.DiscoveredDefs.Terrain.Keys) {
        if ($packageID -eq 'ludeon.rimworld') {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Patches\EW-DesignatorDropdown.xml'
            )
        } else {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                $packageID,
                'Patches\EW-DesignatorDropdown.{0}.xml' -f $packageID
            )
        }

        Confirm-ParentDirectory $path
        [Path]::Combine($buildInfo.Path.Template, 'Patches\EW-DesignatorDropdown.xml') |
            Copy-Item -Destination $path

        $xDocument = [XDocument]::Load($path)
        $parent = $xDocument.Root.Element('Operation').Element('operations')
        $template = $parent.Element('li')

        foreach ($def in $buildInfo.Data.DiscoveredDefs.Terrain[$packageID]) {
            $designatorName = 'EW_Designator_{0}' -f $def.DefName

            $xmlString = $template.ToString() -replace '%NAME%', $def.DefName -replace '%CATEGORY%', $designatorName

            $xElement = [XElement]::new($xmlString)
            $parent.Add($xElement)
        }

        $template.Remove()
        $xDocument.Save($path)
    }
}

function CreateTerrainDef {
    # Terrain defs are added for each wood type implemented by Core.

    foreach ($packageID in $buildInfo.Data.DiscoveredDefs.Terrain.Keys) {
        $commonParams = @{
            Version = $buildInfo.RimWorldVersion.ShortVersion
        }

        if ($packageID -eq 'ludeon.rimworld') {
            $commonParams['SaveAs'] = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Defs\TerrainDefs\EW-Terrain.xml'
            )
        } else {
            $commonParams['SaveAs'] = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                $packageID,
                'Defs\TerrainDefs\EW-Terrain.{0}.xml' -f $packageID
            )

            Confirm-ParentDirectory $commonParams['SaveAs']

            [Path]::Combine($buildInfo.Path.Template, 'Defs\TerrainDefs\EW-Terrain.xml') |
                Copy-Item -Destination $commonParams['SaveAs']

            $buildInfo.Data.AddLoadFoldersEntry($packageID, $packageID)
        }

        foreach ($def in $buildInfo.Data.DiscoveredDefs.Terrain[$packageID]) {
            $designatorName = 'EW_Designator_{0}' -f $def.DefName

            foreach ($wood in $buildInfo.Data.WoodStats) {
                if ($wood.ImplementingMod -notcontains 'ludeon.rimworld') {
                    continue
                }

                $label = $def.XElement.Element('label').Value -replace 'wood(en)?', ('{0} wood' -f $wood.Name.ToLower())
                if ($label -notmatch $wood.Name) {
                    $label = '{0} {1}' -f $wood.Name.ToLower(), $label
                }

                $params = @{
                    NewName = '{0}_{1}' -f $def.DefName, $wood.Name
                    Def     = $def.XElement.ToString()
                    Update  = @{
                        label                                  = $label
                        description                            = $def.XElement.Element('description').Value -replace 'wood(en)?', $wood.DescriptiveName.ToLower() -replace '^.', {
                            $_.Value.ToUpper()
                        }
                        color                                  = $wood.Colour
                        ('costList.WoodLog_{0}' -f $wood.Name) = $def.XElement.Element('costList').Element('WoodLog').Value
                        'designatorDropdown'                   = $designatorName
                    }
                    Remove  = 'costList'
                    SaveAs  = $commonParams['SaveAs']
                }
                Copy-RWModDef @params
            }
        }
    }
}

function CreateTerrainPatch {
    # Terrain patches are added for each wood type added by another mod. Patches are dependent on the existence of the Def.

    foreach ($packageID in $buildInfo.Data.DiscoveredDefs.Terrain.Keys) {
        if ($packageID -eq 'ludeon.rimworld') {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedVersioned,
                'Patches\EW-Terrain.xml'
            )
        } else {
            $path = [Path]::Combine(
                $buildInfo.Path.GeneratedConditionalVersioned,
                $packageID,
                'Patches\EW-Terrain.{0}.xml' -f $packageID
            )

            Confirm-ParentDirectory $path

            [Path]::Combine($buildInfo.Path.Template, 'Patches\EW-Terrain.xml') |
                Copy-Item -Destination $path
        }

        $xDocument = [XDocument]::Load($path)
        $parent = $xDocument.Root.Element('Operation').Element('operations')
        $template = $parent.Element('li')

        foreach ($wood in $buildInfo.Data.WoodStats) {
            if ($wood.ImplementingMod -contains 'ludeon.rimworld') {
                continue
            }

            $xmlString = $template.ToString() -replace '%NAME%', ('WoodLog_{0}' -f $wood.Name)
            $xElement = [XElement]::new($xmlString)
            $parent.Add($xElement)
            $operations = $xElement.Element('match').Element('operations')

            foreach ($def in $buildInfo.Data.DiscoveredDefs.Terrain[$packageID]) {
                $designatorName = 'EW_Designator_{0}' -f $def.DefName

                $label = $def.XElement.Element('label').Value -replace 'wood(en)?', ('{0} wood' -f $wood.Name.ToLower())
                if ($label -notmatch $woodType) {
                    $label = '{0} {1}' -f $wood.Name.ToLower(), $label
                }

                $params = @{
                    NewName = '{0}_{1}' -f $def.DefName, $wood.Name
                    Def     = $def.XElement.ToString()
                    Update  = @{
                        label                                  = $label
                        description                            = $def.XElement.Element('description').Value -replace 'wood(en)?', $wood.DescriptiveName.ToLower() -replace '^.', {
                            $_.Value.ToUpper()
                        }
                        color                                  = $wood.Colour
                        ('costList.WoodLog_{0}' -f $wood.Name) = $def.XElement.Element('costList').Element('WoodLog').Value
                        'designatorDropdown'                   = $designatorName
                    }
                    Remove  = 'costList'
                }
                $newDef = Copy-RWModDef @params
                
                $operations.Add(
                    [XElement]::new(
                        [XName]'li',
                        @(
                            [XAttribute]::new([XName]'Class', 'PatchOperationAdd')
                            [XElement]::new([XName]'xpath', '/Defs')
                            [XElement]::new([XName]'value', $newDef.Root)
                        )
                    )
                )
            }
        }

        $template.Remove()
        $xDocument.Save($path)
    }
}

function CreatePaintedTerrainDef {
    # Painted terrains are treated as a special case, they only patch Core\Floor_WoodPlank and I don't want to extend that.

    $commonParams = @{
        Name    = 'Core\WoodPlankFloor'
        Remove  = 'costList', 'designationHotKey'
        SaveAs  = [Path]::Combine(
            $buildInfo.Path.Painted,
            'Defs\TerrainDefs\EW-WoodFloors-Painted.xml'
        )
        Version = $buildInfo.RimWorldVersion.ShortVersion
    }

    Confirm-ParentDirectory $commonParams['SaveAs']

    foreach ($wood in $buildInfo.Data.WoodPainted) {
        Write-Verbose ('Generating {0} painted floor' -f $wood.Name)

        $params = @{
            NewName = 'WoodPlankFloor_{0}' -f $wood.Name
            Update  = @{
                label                                  = '{0} painted wood floor' -f $wood.Name.ToLower()
                description                            = '{0} wood plank flooring. For that warm, homey feeling.' -f $wood.Name
                color                                  = $wood.Colour
                ('costList.WoodLog_{0}' -f $wood.Name) = 6
                "statBases.Beauty"                     = 2
                'designatorDropdown'                   = 'EW_Designator_WoodPlankFloor'
                texturePath                            = 'Floor/WoodFloorBase'
            }
        }
        Copy-RWModDef @commonParams @params
    }
}

function UpdateCherryPicker {
    $path = [Path]::Combine($buildInfo.Path.GeneratedVersioned, 'Defs/CherryPicker.xml')

    $xDocument = [XDocument]::Load($path)
    $xElement = $xDocument.Element('Defs').
        Element('CherryPicker.DefList').
        Element('defs')

    foreach ($wood in $buildInfo.Data.WoodPainted) {
        $xElement.Add(
            [XElement]::new(
                [XName]'li',
                'ThingDef/WoodLog_{0}' -f $wood.Name
            )
        )
        $xElement.Add(
            [XElement]::new(
                [XName]'li',
                'RecipeDef/PaintWoodLog_{0}' -f $wood.Name
            )
        )
        $xElement.Add(
            [XElement]::new(
                [XName]'li',
                'TerrainDef/WoodPlankFloor_{0}' -f $wood.Name
            )
        )
    }

    $xDocument.Save($path)
}

function UpdateLoadFolders {
    $version = $buildInfo.RimWorldVersion.ShortVersion
    $element = [XElement]::new(
        [XName]('v{0}' -f $version), $buildInfo.Data.LoadFolders.ToXElement()
    )

    $loadFoldersXml = [XDocument]::Load($buildInfo.Path.LoadFolders)
    $loadFolders = $loadFoldersXml.Element('loadFolders')
    if ($existing = $loadFolders.Element($element.Name)) {
        $existing.ReplaceWith($element)
    } else {
        $loadFolders.Add($element)
    }

    $loadFoldersXml.Save($buildInfo.Path.LoadFolders)
    
    Copy-Item $buildInfo.Path.LoadFolders -Destination $buildInfo.Path.Generated
}

function UpdateMetadata {
    $version = $buildInfo.Version
    $version = switch ($ReleaseType) {
        'Major' { [Version]::new($version.Major + 1, 0, 0) }
        'Minor' { [Version]::new($version.Major, $version.Minor + 1, 0) }
        'Build' { [Version]::new($version.Major, $version.Minor, $version.Build + 1) }
    }

    $metadataPath = Join-Path -Path $buildInfo.Path.Generated -ChildPath 'About'

    # About
    $path = Join-Path -Path $psscriptroot -ChildPath 'source\About\About.xml'
    Copy-Item $path -Destination $metadataPath
    $path = Join-Path -Path $metadataPath -ChildPath 'About.xml'

    $xDocument = [XDocument]::Load($path)
    $xElement = $xDocument.Element('ModMetaData').Element('loadAfter')
    $allMods = @(
        foreach ($item in $buildInfo.Data.LoadAfter) {
            Get-RWMod -PackageID $item
        }
        $buildInfo.Data.SupportedMods.Values
        $buildInfo.Data.SupportedFloorMods
    ) | Sort-Object PackageId
    foreach ($modInfo in $allMods) {
        if (-not $modInfo.PackageId) {
            continue
        }

        $xElement.Add(
            [XElement]::new(
                [XName]'li',
                $modInfo.PackageId
            )
        )
    }

    $xElement = $xDocument.Element('ModMetaData').Element('description')
    $xElement.Value = $xElement.Value -replace '%SUPPORTED_MODS%', @(
        ($buildInfo.Data.SupportedMods.Values.Name -notmatch '^(Core|Royalty|Ideology|Biotech|Anomaly)$' |
            Sort-Object |
            ForEach-Object { '* {0}' -f $_ }) -join "`n"
    )
    $xElement.Value = $xElement.Value -replace '%SUPPORTED_FLOOR_MODS%', @(
        ($buildInfo.Data.SupportedFloorMods.Name -notmatch '^(Core|Royalty|Ideology|Biotech|Anomaly)$' |
            Sort-Object |
            ForEach-Object { '* {0}' -f $_ }) -join "`n"
    )

    $xDocument.Save($path)

    # Manifest
    $path = Join-Path -Path $psscriptroot -ChildPath 'source\About\Manifest.xml'
    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $xDocument.Element('Manifest').Element('version').Value = $version
    $xDocument.Save($path)
    Copy-Item $path -Destination $metadataPath

    # ModSync
    $path = Join-Path -Path $psscriptroot -ChildPath 'source\About\ModSync.xml'
    $xDocument = [System.Xml.Linq.XDocument]::Load($path)
    $xDocument.Descendants('Version').ForEach{ $_.Value = $version }
    $xDocument.Save($path)
    Copy-Item $path -Destination $metadataPath
}

function CreatePackage {
    $params = @{
        Path            = $buildInfo.Path.Generated
        DestinationPath = Join-Path $buildInfo.Path.Build ('{0}.zip' -f $buildInfo.Name)
    }
    Compress-Archive @params
}

function UpdateLocal {
    $path = Get-RWGamePath
    $modPath = [System.IO.Path]::Combine($path, 'Mods', $buildInfo.Name)

    if (Test-Path $modPath) {
        Remove-Item $modPath -Recurse
    }

    Copy-Item $buildInfo.Path.Generated "$path\Mods" -Recurse -Force
}


function WriteMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Message,

        [ValidateSet('Information', 'Warning', 'Error')]
        [string]
        $Category = 'Information',

        [string]
        $Details
    )

    process {
        $params = @{
            Object          = ('{0}: {1}' -f $Message, $Details).TrimEnd(' :')
            ForegroundColor = switch ($Category) {
                'Information' { 'Cyan' }
                'Warning' { 'Yellow' }
                'Error' { 'Red' }
            }
        }
        Write-Host @params
    }
}

function InvokeTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $TaskName
    )

    begin {
        Write-Host ('Build {0}' -f $PSCommandPath) -ForegroundColor Green
    }

    process {
        $ErrorActionPreference = 'Stop'
        try {
            $stopWatch = [Stopwatch]::StartNew()

            WriteMessage -Message ('Task {0}' -f $TaskName)
            & "Script:$TaskName"
            WriteMessage -Message ('Done {0} {1}' -f $TaskName, $stopWatch.Elapsed)
        } catch {
            WriteMessage -Message ('Failed {0} {1}' -f $TaskName, $stopWatch.Elapsed) -Category Error -Details $_.Exception.Message

            exit 1
        } finally {
            $stopWatch.Stop()
        }
    }
}

$TaskName | InvokeTask
