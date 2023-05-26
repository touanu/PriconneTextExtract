"Database{0,-29}ID{0,-22}Texts{0,-32}Status`n" -f ""
Get-ChildItem .\csv | ForEach-Object -Parallel {
    $db = Import-Csv $_
    if (Test-Path ".\en_csv\$($_.Name)" -PathType Leaf) {
        $endb = Import-Csv ".\en_csv\$($_.Name)"
    }
    else {
        $endb = $null
    }

    # Finding key and JP text properties
    $properties = $db[0].PSObject.Properties
    $id = $properties.Name[0]
    $texts = [System.Collections.ArrayList]@()
    foreach ($property in $properties) {
        if ($property.Value -match "[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]") {
            $null = $texts.Add($property.Name)
        }
    }

    if ($texts) {
        if (Test-Path -PathType Leaf ".\jp\$($_.BaseName).txt") {
            Remove-Item ".\jp\$($_.BaseName).txt"
        }
        if (Test-Path -PathType Leaf ".\jp_en\$($_.BaseName).txt") {
            Remove-Item ".\jp_en\$($_.BaseName).txt"
        }

        foreach ($text in $texts) {
            # Add translated texts from global datamined db
            $db | . { process {
                $jp_id = $_.$id
                $entext = $endb.Where({ $_.$id -eq $jp_id }) | Select-Object -ExpandProperty $text
                $_ | Add-Member -Force -NotePropertyName "$text-translated" -NotePropertyValue $entext
            }}

            # Remove duplicated texts
            $sorted_db = $db | Group-Object $text | ForEach-Object {
                $_.Group | Select-Object $text, "$text-translated" -First 1
            }

            # Write to 2 different files: under "jp" folder for only JP texts and under "jp_en" folder for JP and translated texts
            Add-Content -Force -Path ".\jp\$($_.BaseName).txt" -Value ($sorted_db.$text -join "=`n")
            if ($null -ne $id -or $null -ne $endb) {
                $output = [System.Text.StringBuilder]""
                $sorted_db | . { process {
                        if ($_.$text) {
                            $null = $output.AppendLine("$($_.$text)=$($_."$text-translated")")
                        }
                    }
                }
                Add-Content -Force -Path ".\jp_en\$($_.BaseName).txt" -Value ($output.ToString())
            }
        }
        $status = "OK!"
    }
    else {
        $status = "Skipped!"
    }

    if ($texts[1]) {
        $texts_info = "{0}, {1}" -f $texts[0], $texts[1]
    }
    else {
        $texts_info = "{0}" -f $texts[0]
    }
    "{1,-37}{2,-24}{3,-37}{4}" -f "", $_.Name, $id, $texts_info, $status
}
