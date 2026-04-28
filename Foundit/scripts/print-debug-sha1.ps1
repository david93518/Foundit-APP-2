# 輸出 Debug keystore 的 SHA-1 / SHA-256（供 Google Cloud「Android OAuth 用戶端」使用）
$keystore = Join-Path $env:USERPROFILE ".android\debug.keystore"
if (-not (Test-Path $keystore)) {
    Write-Error "找不到 Debug keystore：$keystore （請先用 Android Studio 建置或執行過 App）"
    exit 1
}

$msJdk = Get-ChildItem "C:\Program Files\Microsoft" -Directory -Filter "jdk-*" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
$msKeytool = if ($msJdk) { Join-Path $msJdk.FullName "bin\keytool.exe" } else { $null }

$keytoolCandidates = @(
    $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\keytool.exe" }),
    $msKeytool,
    "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
)
$keytool = $keytoolCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $keytool) {
    Write-Error "找不到 keytool.exe。請安裝 JDK 17+ 或 Android Studio，或設定 JAVA_HOME。"
    exit 1
}

Write-Host "使用：$keytool"
Write-Host "Keystore：$keystore"
& $keytool -list -v -keystore $keystore -alias androiddebugkey -storepass android -keypass android
