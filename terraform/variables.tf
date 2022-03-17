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

variable "service_account_id" {
  description = "Service account Id"
  type        = string
}
