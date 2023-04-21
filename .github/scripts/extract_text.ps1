Get-ChildItem .\csv | ForEach-Object -Parallel {
    $db = Import-Csv $_
    if (Test-Path ".\en_csv\$($_.Name)" -PathType Leaf) {
        $endb = Import-Csv ".\en_csv\$($_.Name)"
    }
    else {
        $endb = $null
    }

    $properties = $db[0].PSObject.Properties
    $id = $properties.Name[0]
    $texts = [System.Collections.ArrayList]@()
    foreach ($property in $properties) {
        if ($property.Value -match "[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]") {
            $null = $texts.Add($property.Name)
            continue
        }
    }

    $db_sorted = $db | Sort-Object -Unique $texts

    if ($texts) {
        foreach ($text in $texts) {
            Set-Content -Force -Path ".\jp\$($_.BaseName).txt" -Value ($db_sorted.$text -join "=`n")
            if ($null -ne $id -or $null -ne $endb) {
                if (Test-Path -PathType Leaf ".\jp_en\$($_.BaseName).txt") {
                    Remove-Item ".\jp_en\$($_.BaseName).txt"
                }
                $output = [System.Text.StringBuilder]""
                $db_sorted | . { process {
                        $jp_id = $_.$id
                        $jp = $_.$text
                        $en = $endb.Where({ $_.$id -eq $jp_id }) | Select-Object -ExpandProperty $text
                        $null = $output.AppendLine("$jp=$en")
                    }
                }
                Add-Content -Force -Path ".\jp_en\$($_.BaseName).txt" -Value ($output.ToString())
            }
        }
        Write-Output "Extracted $($_.Name)"
    }
    else {
        Write-Output "$($_.Name) doesn't have JP text. Skipped!"
    }
}