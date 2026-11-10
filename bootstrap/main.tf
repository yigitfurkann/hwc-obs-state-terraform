# State bucket'ını BİR KEZ oluşturur. Bu klasör yerel state ile çalışır,
# çünkü henüz state'i koyacak bucket yoktur. Oluşan bootstrap/terraform.tfstate
# dosyasını güvenli bir yerde saklayın (Git'e eklenmez).

terraform {
  required_version = ">= 1.6.3"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = ">= 1.60.0"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}

variable "region" {
  description = "Huawei Cloud bölge kodu (TR-Istanbul = tr-west-1)"
  type        = string
  default     = "tr-west-1"
}

variable "bucket_name" {
  description = "State bucket adı. Tüm Huawei Cloud genelinde benzersiz olmalı."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket adı 3-63 karakter olmalı; küçük harf, rakam, nokta ve tire içerebilir."
  }
}

resource "huaweicloud_obs_bucket" "tf_state" {
  bucket        = var.bucket_name
  acl           = "private"
  storage_class = "STANDARD"
  versioning    = true

  # SSE-OBS sunucu tarafı şifreleme (KMS anahtarı gerektirmez)
  encryption    = true
  sse_algorithm = "AES256"

  # WORM (object lock) KAPALI: bu kaynakta WORM ayarı yoktur, bucket WORM'suz açılır.
  # WORM açık bir bucket'ta nesneler saklama süresi dolana kadar silinemez — açmayın.

  # Bucket silinirken içindeki nesneleri de silmeyi dener. Not: provider 1.100.0 ile
  # versiyonlu bucket'larda "MalformedXML" hatası alındı; silmeden önce bucket'ı
  # konsoldan (Historical Versions açıkken) boşaltın. Ayrıntı: README > Temizlik.
  force_destroy = true

  # Terraform tarafında yanlışlıkla silmeyi engeller (sadece Terraform'u bağlar,
  # konsoldan silmeyi engellemez). Bucket'ı bilerek silmek için bu bloğu kaldırıp
  # "terraform destroy" çalıştırın.
  lifecycle {
    prevent_destroy = true
  }
}

output "bucket_name" {
  value = huaweicloud_obs_bucket.tf_state.bucket
}
