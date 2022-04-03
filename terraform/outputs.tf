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
  description = "Availability zone for Yandex resources."
}

output "folder_id" {
  value       = var.folder_id
  description = "Yandex Folder Id."
}

output "data_bucket_name" {
  value       = yandex_storage_bucket.data-lake.bucket
  description = "S3 bucket name for data lake."
}

output "dp_bucket_name" {
  value       = yandex_storage_bucket.dataproc-bucket.bucket
  description = "S3 bucket name for dataproc spark cluster."
}

output "dp_subnet_id" {
  value       = yandex_vpc_subnet.clickhouse-subnet.id
  description = "Subnet for clickhouse and dataproc clusters."
  sensitive   = true
}

output "dp_sa_id" {
  value       = yandex_iam_service_account.dataproc-sa.id
  description = "Service account for dataproc spark cluster."
  sensitive   = true
}

output "clickhouse_cluster_id" {
  value       = yandex_mdb_clickhouse_cluster.clickhouse.id
  description = "Id of the Clickhouse Cluster"
}

output "clickhouse_db_name" {
  value       = var.clickhouse_db_name
  description = "Clickhouse Database Name."
  sensitive   = true
}

output "clickhouse_username" {
  value       = var.clickhouse_username
  description = "Clickhouse Username."
  sensitive   = true
}

output "clickhouse_password" {
  value       = var.clickhouse_password
  description = "Clickhouse User Password."
  sensitive   = true
}