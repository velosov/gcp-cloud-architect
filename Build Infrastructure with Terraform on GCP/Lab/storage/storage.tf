resource "google_storage_bucket" "tf-bucket-746130" {
  name          = "tf-bucket-746130"
  location      = "US"
  force_destroy = true
  uniform_bucket_level_access = true
}
