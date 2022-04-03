variable "cloud_id" {
  description = "Yandex Cloud Id"
  type        = string
}

variable "folder_id" {
  description = "Yandex Folder Id"
  default     = "b1gl4lsgd698odl01pn3"
  type        = string
}

variable "zone" {
  description = "Availability zone for Yandex resources"
  default     = "ru-central1-a"
  type        = string
}

variable "clickhouse_db_name" {
  description = "Name for clickhouse database"
  default     = "dwh"
  type        = string
}

variable "clickhouse_username" {
  description = "Username for clickhouse database"
  type        = string
  sensitive   = true
}


variable "clickhouse_password" {
  description = "Password for clickhouse database"
  type        = string
  sensitive   = true
}

variable "sasl_username" {
  description = "SASL username for Kafka"
  type        = string
  sensitive   = true
}

variable "sasl_password" {
  description = "SASL password for Kafka"
  type        = string
  sensitive   = true
}

variable "rabbit_user" {
  description = "User for Rabbit"
  type        = string
  sensitive   = true
}

variable "rabbit_password" {
  description = "Password for Rabbit"
  type        = string
  sensitive   = true
}