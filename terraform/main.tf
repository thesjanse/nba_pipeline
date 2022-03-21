terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.0"
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

# create object storage service account
resource "yandex_iam_service_account" "storage-sa" {
  name        = "storage-sa"
  description = "Service account for object storage management."
  folder_id   = var.folder_id
}

# provide role for object storage service account
resource "yandex_resourcemanager_folder_iam_binding" "storage-uploader-iam" {
  folder_id = var.folder_id
  role      = "storage.admin"

  members = [
    "serviceAccount:${yandex_iam_service_account.storage-sa.id}"
  ]
}

# create static access key
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.storage-sa.id
  description        = "Static Access Key for object storage."
}

# initialize bucket
resource "yandex_storage_bucket" "data-lake" {
  bucket        = "nba-${var.folder_id}"
  force_destroy = true
  access_key    = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key    = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
}