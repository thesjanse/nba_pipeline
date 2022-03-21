output "bucket_name" {
  value       = yandex_storage_bucket.data-lake.bucket
  description = "Name of data lake s3 bucket."
}

output "object_storage_sa_access_key" {
  value       = yandex_storage_bucket.data-lake.access_key
  description = "Object storage access key for the data lake s3 bucket."
  sensitive   = true
}

output "object_storage_sa_secret_key" {
  value       = yandex_storage_bucket.data-lake.secret_key
  description = "Object storage secret key for the data lake s3 bucket."
  sensitive   = true
}

output "zone" {
  value       = var.zone
  description = "Availability zone for Yandex resources"
}