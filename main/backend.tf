# OBS, S3 API uyumlu olduğu için Terraform'un yerleşik "s3" backend'i kullanılır.
# bucket ve key değerleri ortama göre değiştiği için backend.hcl dosyasından gelir:
#   terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    region = "tr-west-1"

    endpoints = {
      s3 = "https://obs.tr-west-1.myhuaweicloud.com"
    }

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
