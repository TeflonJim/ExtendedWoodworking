Get-RWModDef -ModName $SourceModName -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($_.DefType -eq 'ThingDef' -and
            (
                $_.XElement.Element('category').Value -eq 'Building' -or
                $_.XElement.Element('thingClass').Value -like 'Building*'
            ) -and
            $_.XElement.Element('costList') -and
            $_.XElement.Element('costList').Element('WoodLog') -and
            -not $_.XElement.Element('stuffCategories')
        ) {
            $content = Get-Content "$build\Patches\EW-%NAME%_costList.xml" -Raw
            $content = $content -replace '%NAME%', $_.DefName
            $content = $content -replace '%COST%', $_.XElement.Element('costList').Element('WoodLog').Value
            Set-Content -Path "$build\Patches\EW-$($_.DefName)_costList.xml" -Value $content
        } elseif (($_.DefName -replace 'PlantTree') -in $natural) {
            $content = Get-Content "$build\Patches\EW-%NAME%_harvestedThingDef.xml" -Raw
            $content = $content -replace '%NAME%', ($_.DefName -replace 'PlantTree')
            Set-Content -Path "$build\Patches\EW-$($_.DefName)_harvestedThingDef.xml" -Value $content
        }
    }

$path = "$build\Patches\EW-Building_CompProperties_Refuelable.xml"
$xDocument = [System.Xml.Linq.XDocument]::Load($path)
foreach ($woodLog in $allWood) {
    $xDocument.Descendants('thingDefs'). Add((
        New-Object System.Xml.Linq.XElement(
            New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]'li'),
            $woodLog
        )
    ))
}
$xDocument.Save($path)