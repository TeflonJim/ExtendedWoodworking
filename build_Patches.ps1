foreach ($mod in $supportedMods) {
    $modInfo = Get-RWMod $mod
    $shortName = $mod -replace '[^A-Za-z]'

    Get-ChildItem (Join-Path $modInfo.Path 'Defs') -Filter *.xml -Recurse | ForEach-Object {
        Select-Xml -Path $_.FullName -XPath '/Defs/*[defName and not(stuffCategories)]/costList[WoodLog]'
    } | ForEach-Object {
        $def = $_.Node.ParentNode

        $content = Get-Content "$build\Patches\EW-%NAME%_costList.xml" -Raw
        $content = $content -replace '%NAME%', $def.defName
        $content = $content -replace '%COST%', $def.costList.WoodLog
        Set-Content -Path "$build\Patches\EW-$shortName-$($def.DefName)_costList.xml" -Value $content
    }
}

foreach ($mod in $supportedMods) {
    $modInfo = Get-RWMod $mod
    $shortName = $mod -replace '[^A-Za-z]'

    Get-ChildItem (Join-Path $modInfo.Path 'Defs') -Filter *.xml -Recurse |
        ForEach-Object {
            Select-Xml -Path $_.FullName -XPath '/Defs/*[contains(defName, "PlantTree")]'
        } |
        Where-Object { $woodStats.Contains(($_.Node.defName -replace 'PlantTree')) } |
        ForEach-Object {
            $def = $_.Node

            $content = Get-Content "$build\Patches\EW-%NAME%_harvestedThingDef.xml" -Raw
            $content = $content -replace '%NAME%', ($def.DefName -replace 'PlantTree')
            Set-Content -Path "$build\Patches\EW-$shortName-$($def.DefName)_harvestedThingDef.xml" -Value $content
        }
}

# $path = "$build\Patches\EW-Building_CompProperties_Refuelable.xml"
# $xDocument = [System.Xml.Linq.XDocument]::Load($path)
# foreach ($woodLog in $allWood) {
#     $xDocument.Descendants('thingDefs'). Add((
#         New-Object System.Xml.Linq.XElement(
#             New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]'li'),
#             $woodLog
#         )
#     ))
# }
# $xDocument.Save($path)