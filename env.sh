#!/usr/bin/env bash
# Ortam değişkenlerini yükler. Kullanım (proje kökünde):  source ./env.sh
# huaweicloud provider HW_* değişkenlerini, S3 backend ise AWS_* değişkenlerini okur;
# bu script ikisini aynı AK/SK'dan üretir. env.ps1'in Linux / macOS / WSL / CI karşılığıdır.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/secrets.sh"

if [ -f "$SECRETS_FILE" ]; then
  # shellcheck source=/dev/null
  . "$SECRETS_FILE"
fi

for name in HW_ACCESS_KEY HW_SECRET_KEY TF_STATE_BUCKET; do
  value="${!name}"
  if [ -z "$value" ] || [[ "$value" == *_DEGERINIZ ]]; then
    echo "$name tanımlı değil veya örnek değerde kalmış. secrets.sh dosyasını doldurun (veya CI secret olarak tanımlayın)." >&2
    return 1 2>/dev/null || exit 1
  fi
done

export HW_REGION_NAME="${HW_REGION_NAME:-tr-west-1}"
export AWS_ACCESS_KEY_ID="$HW_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$HW_SECRET_KEY"
export TF_VAR_bucket_name="$TF_STATE_BUCKET"

# Yeni AWS SDK varsayılan olarak ek checksum başlıkları gönderir; OBS bunları desteklemez
# ve state yüklemesi XAmzContentSHA256Mismatch hatası verir. Sadece gerektiğinde gönder:
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

# main/backend.hcl dosyasını bucket adından üret
printf 'bucket = "%s"\nkey    = "main/terraform.tfstate"\n' "$TF_STATE_BUCKET" > "$SCRIPT_DIR/main/backend.hcl"

echo "Ortam hazır. Bölge: $HW_REGION_NAME  Bucket: $TF_STATE_BUCKET"
