#
# RecipeDefs
#

# WoodLog (painted)

$path = "$build\Defs\RecipeDefs\EW-Woodworking.xml"

$xDocument = [System.Xml.Linq.XDocument]::Load($path)
$template = $xDocument.Root.Elements('RecipeDef').Where( { $_.Element('defName').Value -eq 'PaintWoodLogTemplate' } )[0]

foreach ($colour in $painted.Keys) {
    $recipe = New-Object System.Xml.Linq.XElement($template)

    $recipe.Element('defName').SetValue("PaintWoodLog_$colour")
    $recipe.Element('label').SetValue(('paint wood {0}' -f $colour.ToLower()))
    $recipe.Element('description').SetValue(('Paints wood {0}' -f $colour.ToLower()))
    $recipe.Element('products').Add((
        New-Object System.Xml.Linq.XElement(
            New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]"WoodLog_$colour"),
            25
        )
    ))
    $painted.Keys | Where-Object { $_ -ne $colour } | ForEach-Object {
        $recipe.Element('defaultIngredientFilter').
                Element('exceptedThingDefs').
                Add((
                    New-Object System.Xml.Linq.XElement(
                        New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]'li'),
                        "WoodLog_$_"
                    )
                ))
    }

    $xDocument.Root.Add($recipe)
}

# Remove the template

$template.Remove()

$xDocument.Save($path)

