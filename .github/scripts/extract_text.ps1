"Database{0,-83}Status`n" -f ""
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
        $texts_info = [System.Text.StringBuilder]"`n- texts: "
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
                $entext = $endb.Where({ $_.$id -eq $jp_id}) | Select-Object -ExpandProperty $text
                if ($entext -notmatch "([\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]|^\?+$|^？+$|^\s*$)") {
                    $_ | Add-Member -Force -NotePropertyName "$text-translated" -NotePropertyValue $entext
                }
            }}

            # Remove duplicated texts
            $sorted_db = $db | Group-Object $text | . { process {
                if ($_.Name -notmatch "(^？+$|^\s*$)") {
                    $_.Group | Sort-Object $text, "$text-translated" -Descending | Select-Object $text, "$text-translated" -First 1
                }
            }}

            # Write to 2 different files: under "jp" folder for only JP texts and under "jp_en" folder for JP and translated texts
            Add-Content -Force -Path ".\jp\$($_.BaseName).txt" -Value ($sorted_db.$text -join "=`n")
            if ($null -ne $id -or $null -ne $endb) {
                $output = [System.Text.StringBuilder]""
                $sorted_db | . { process {
                            $null = $output.AppendLine("$($_.$text)=$($_."$text-translated")")
                        }
                }
                Add-Content -Force -Path ".\jp_en\$($_.BaseName).txt" -Value ($output.ToString())
            }

            if ($text -eq $texts[0]) {
                $null = $texts_info.Append("$text")
            }
            else {
                $null = $texts_info.Append(", $text")
            }
        }
        $status = "OK!"
    }
    else {
        $texts_info = ""
        $status = "Skipped!"
    }
    "{0,-91}{3}`n- id: {1}{2}`n" -f $_.Name, $id, $texts_info, $status
}
