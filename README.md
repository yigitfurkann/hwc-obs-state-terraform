# Huawei Cloud OBS'de Terraform State (TR-Istanbul)

Terraform state dosyasını Huawei Cloud **OBS (Object Storage Service)** üzerinde, **TR-Istanbul (`tr-west-1`)** bölgesinde tutan, gerçek bir hesapta test edilmiş kurulum.

OBS, S3 API uyumlu olduğu için ayrı bir backend gerekmez: Terraform'un yerleşik `s3` backend'i, OBS endpoint'i ve birkaç `skip_*` ayarıyla doğrudan OBS'ye yazar ([Huawei Cloud resmi dokümanı](https://support.huaweicloud.com/basics-terraform/terraform_0021.html)).

| Bilgi | Değer |
|---|---|
| Bölge | TR-Istanbul (`tr-west-1`) |
| OBS endpoint | `https://obs.tr-west-1.myhuaweicloud.com` |
| Terraform | `>= 1.6.3` (1.17.0 ile test edildi) |
| huaweicloud provider | `>= 1.60.0` (1.100.0 ile test edildi) |

## Proje yapısı

```
.
├── .gitignore
├── .gitattributes
├── env.ps1                  # Windows: ortam değişkenlerini yükler, main/backend.hcl üretir
├── env.sh                   # Linux / macOS / WSL / CI karşılığı
├── secrets.ps1.example      # AK/SK şablonu (Windows)
├── secrets.sh.example       # AK/SK şablonu (bash)
├── bootstrap/               # state bucket'ını BİR KEZ oluşturur (yerel state)
│   ├── main.tf
│   └── .terraform.lock.hcl
└── main/                    # asıl altyapı (state OBS'de)
    ├── versions.tf
    ├── backend.tf           # s3 backend + OBS endpoint
    ├── backend.hcl.example  # env script'leri gerçek backend.hcl'i üretir
    ├── provider.tf
    ├── main.tf              # örnek: test VPC'si
    └── .terraform.lock.hcl
```

- **`bootstrap/`**: State bucket'ını oluşturur. Henüz state'i koyacak bucket olmadığı için kendi state'ini yerelde tutar. Bucket private, versiyonlu, SSE-OBS ile şifreli ve `prevent_destroy` ile korumalıdır.
- **`main/`**: Asıl altyapı. State'i `s3://<bucket>/main/terraform.tfstate` yolunda tutar.
- **AK/SK hiçbir `.tf` dosyasında yer almaz.** `secrets.ps1` / `secrets.sh` dosyaları `.gitignore`'dadır.

## Ön koşullar

1. **Terraform 1.6.3+**
   - Windows: `winget install Hashicorp.Terraform` (kurulumdan sonra terminali yeniden açın)
   - macOS: `brew install terraform`
   - Kontrol: `terraform -version`
2. **IAM kullanıcısı (programatik erişim)**: Konsol → IAM
   - **User Groups → Create User Group**: `terraform-ops`
   - Gruba politika atayın: **OBS Administrator** (bucket'ı Terraform ile oluşturmak için) ve örnek VPC için **VPC FullAccess**
   - **Users → Create User**: `terraform-bot`, *Access Type* = **Programmatic access**, *Credential Type* = **Access key**, grubu `terraform-ops`
3. **AK/SK**: IAM → Users → `terraform-bot` → **Security Settings → Access Keys → Create Access Key** → `credentials.csv` dosyasını indirin. Secret Key yalnızca bu anda indirilebilir.

> Neden iki farklı değişken seti? **huaweicloud provider `HW_*`**, **S3 backend ise `AWS_*`** değişkenlerini okur. `env.ps1` / `env.sh` ikisini aynı AK/SK'dan üretir; yalnızca birini tanımlarsanız ya kaynak oluşturma ya da state yazma hata verir.

## Kurulum: Windows (PowerShell)

### 1. Repoyu alın ve kimlik bilgilerini girin

```powershell
git clone https://github.com/yigitfurkann/hwc-obs-state-terraform.git
cd hwc-obs-state-terraform
Copy-Item secrets.ps1.example secrets.ps1
code secrets.ps1     # AK, SK ve benzersiz bir bucket adı yazıp kaydedin
```

### 2. Ortamı yükleyin (her yeni terminalde)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. .\env.ps1          # baştaki nokta ve boşluk önemli
```

Beklenen çıktı:

```
Ortam hazır. Bölge: tr-west-1  Bucket: <bucket-adınız>
```

### 3. State bucket'ını oluşturun (bir kez)

```powershell
cd bootstrap
terraform init
terraform plan
terraform apply      # onay için: yes
cd ..
```

Beklenen çıktı:

```
huaweicloud_obs_bucket.tf_state: Creation complete after 3s [id=<bucket-adınız>]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

> Oluşan `bootstrap/terraform.tfstate` bucket'ın kendi state'idir. Silmeyin ve güvenli bir yerde saklayın.
> Bucket'ı konsoldan açmayı tercih ederseniz bu adımı atlayın. Ancak **WORM seçeneğini kapalı bırakın**, **Versioning**'i açın.

### 4. Ana projeyi OBS backend'ine bağlayın

```powershell
cd main
terraform init "-backend-config=backend.hcl"   # tırnak şart, aşağıya bakın
```

Beklenen çıktı:

```
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

### 5. Plan ve apply

```powershell
terraform plan       # Plan: 1 to add
terraform apply      # onay için: yes
```

## Kurulum: Linux / macOS / WSL (bash)

```bash
git clone https://github.com/yigitfurkann/hwc-obs-state-terraform.git
cd hwc-obs-state-terraform
cp secrets.sh.example secrets.sh && vi secrets.sh
source ./env.sh

cd bootstrap && terraform init && terraform apply && cd ..
cd main && terraform init -backend-config=backend.hcl && terraform apply
```

**CI/CD**: `secrets.sh` yerine `HW_ACCESS_KEY`, `HW_SECRET_KEY`, `TF_STATE_BUCKET` değerlerini pipeline secret'ı olarak tanımlayıp `source ./env.sh` çalıştırın.

## Doğrulama

```powershell
terraform state list     # huaweicloud_vpc.test
terraform plan           # No changes. Your infrastructure matches the configuration.
```

- Konsol → **OBS** → bucket → **Objects** → `main/terraform.tfstate` görünmeli.
- Konsol → **VPC → My VPCs** (TR-Istanbul) → `tf-state-test-vpc` görünmeli.
- `main/` klasöründe yerel bir `terraform.tfstate` dosyası **olmamalı**.

## Kendi altyapınızı eklemek

`main/main.tf` içindeki test VPC'sini silip kendi kaynaklarınızı `main/` altına `.tf` dosyaları olarak ekleyin. Farklı proje veya ortamlar için `backend.hcl` içindeki `key` değerini değiştirin (ör. `prod/network/terraform.tfstate`).

## Temizlik

```powershell
cd main
terraform destroy                # test VPC'si silinir, state OBS'de boş olarak kalır
```

Bucket'ı da tamamen kaldırmak için:

1. Konsol → OBS → bucket → **Objects** → **Historical Versions** anahtarını açın ve tüm nesneleri, tüm sürümleriyle birlikte silin (Fragments sekmesini de kontrol edin).
2. `bootstrap/main.tf` içindeki `lifecycle { prevent_destroy = true }` bloğunu silin. Resource'u kapatan `}` parantezine dokunmayın.
3. `cd bootstrap` ve ardından `terraform destroy`.

> `force_destroy = true` ayarlı olsa da provider 1.100.0, versiyonlu bucket'ı boşaltırken `MalformedXML` hatası verdi. Bu yüzden 1. adım gerekli.

## Sorun giderme

| Hata | Neden | Çözüm |
|---|---|---|
| `XAmzContentSHA256Mismatch` / `Failed to save state` | Yeni AWS SDK'nın gönderdiği checksum başlıklarını OBS desteklemiyor | `env` script'i `AWS_REQUEST_CHECKSUM_CALCULATION` ve `AWS_RESPONSE_CHECKSUM_VALIDATION` değişkenlerini `when_required` yapar. **`apply`'ı tekrar çalıştırmayın**; `terraform state push errored.tfstate` ile state'i gönderin. |
| `No positional arguments are expected` | PowerShell `-backend-config=backend.hcl` argümanını noktadan böler | `terraform init "-backend-config=backend.hcl"` |
| `An Application Control policy has blocked this file` | Windows Smart App Control, imzasız provider exe'sini engelliyor | WSL içinden çalıştırın veya izin verilen kopyaya junction verin (aşağıda) |
| `terraform` tanınmıyor | Terminal, kurulumdan önce açılmış | Terminali / VS Code'u yeniden başlatın |
| `running scripts is disabled` | PowerShell execution policy | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |
| `No valid credential sources found` | `AWS_*` değişkenleri yok | `. .\env.ps1` veya `source ./env.sh` |
| `AccessDenied` / 403 | IAM politikası eksik | Gruba OBS politikasını ekleyin |
| `NoSuchBucket` | Bucket yok veya başka bölgede | `bootstrap` adımını çalıştırın |
| `BucketAlreadyExists` | Bucket adı başka hesapta kullanılıyor | `secrets` dosyasında adı değiştirin |
| `Instance cannot be destroyed` | `prevent_destroy` açık | Temizlik bölümündeki 2. adım |
| `MalformedXML` (bucket silerken) | Versiyonlu nesneler toplu silinemedi | Temizlik bölümündeki 1. adım |

Smart App Control için junction örneği (`bootstrap/` içindeki kopya çalışıyor, `main/` içindeki engelleniyorsa):

```powershell
$rel = '.terraform\providers\registry.terraform.io\huaweicloud\huaweicloud\1.100.0\windows_amd64'
Remove-Item -Recurse -Force "main\$rel"
New-Item -ItemType Junction -Path "main\$rel" -Target "$PWD\bootstrap\$rel"
```

## Notlar

- **State kilitleme**: OBS'de DynamoDB karşılığı yoktur ve bu kurulum kilitleme yapmaz. Terraform 1.10+ ile gelen `use_lockfile = true` seçeneğini önce test ortamında deneyin. Kilitleme yoksa aynı state üzerinde eşzamanlı `apply` çalışmasını CI/CD tarafında engelleyin.
- **Terraform < 1.6**: `endpoints = { s3 = ... }` yerine `endpoint = "..."` kullanın ve `skip_requesting_account_id` ile `skip_s3_checksum` satırlarını kaldırın.
- **Terragrunt**: `remote_state` bloğu OBS ile hata verir. Bunun yerine `generate "backend"` ile `backend.tf` üretin.

## Kaynaklar

- [Huawei Cloud: Terraform Backend](https://support.huaweicloud.com/basics-terraform/terraform_0021.html)
- [huaweicloud Terraform provider](https://registry.terraform.io/providers/huaweicloud/huaweicloud/latest/docs)
- [Terraform: S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
