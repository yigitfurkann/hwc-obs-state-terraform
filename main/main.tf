# Kurulumu doğrulamak için ücretsiz bir test VPC'si.
resource "huaweicloud_vpc" "test" {
  name = "tf-state-test-vpc"
  cidr = "10.10.0.0/16"
}

output "vpc_id" {
  value = huaweicloud_vpc.test.id
}
