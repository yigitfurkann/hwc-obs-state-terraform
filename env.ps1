# Ortam değişkenlerini yükler. Kullanım (proje kökünde):  . .\env.ps1
# huaweicloud provider HW_* değişkenlerini, S3 backend ise AWS_* değişkenlerini okur;
# bu script ikisini aynı AK/SK'dan üretir.

$secretsFile = Join-Path $PSScriptRoot 'secrets.ps1'
if (-not (Test-Path $secretsFile)) {
    throw "secrets.ps1 bulunamadı. Önce: Copy-Item secrets.ps1.example secrets.ps1 ve değerleri doldurun."
}
. $secretsFile

foreach ($name in 'HW_ACCESS_KEY', 'HW_SECRET_KEY', 'TF_STATE_BUCKET') {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '_DEGERINIZ$') {
        throw "$name tanımlı değil veya örnek değerde kalmış. secrets.ps1 dosyasını doldurun."
    }
}

if (-not $env:HW_REGION_NAME) { $env:HW_REGION_NAME = 'tr-west-1' }
$env:AWS_ACCESS_KEY_ID     = $env:HW_ACCESS_KEY
$env:AWS_SECRET_ACCESS_KEY = $env:HW_SECRET_KEY
$env:TF_VAR_bucket_name    = $env:TF_STATE_BUCKET

# Yeni AWS SDK varsayılan olarak ek checksum başlıkları gönderir; OBS bunları desteklemez
# ve state yüklemesi XAmzContentSHA256Mismatch hatası verir. Sadece gerektiğinde gönder:
$env:AWS_REQUEST_CHECKSUM_CALCULATION = 'when_required'
$env:AWS_RESPONSE_CHECKSUM_VALIDATION = 'when_required'

# main/backend.hcl dosyasını bucket adından üret
$backendHcl = Join-Path $PSScriptRoot 'main\backend.hcl'
@(
    "bucket = `"$($env:TF_STATE_BUCKET)`""
    'key    = "main/terraform.tfstate"'
) | Set-Content -Path $backendHcl -Encoding ascii

Write-Host "Ortam hazır. Bölge: $($env:HW_REGION_NAME)  Bucket: $($env:TF_STATE_BUCKET)" -ForegroundColor Green
