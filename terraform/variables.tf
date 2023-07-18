variable "token" {
  description = "Yandex Cloud token"
  type        = string
  sensitive   = true
}

variable "cloud_id" {
  description = "Yandex Cloud cloud_id"
  type        = string
  sensitive   = true
}

variable "folder_id" {
  description = "Yandex Cloud folder_id"
  type        = string
  sensitive   = true
}

variable "network_id" {
  description = "Yandex Cloud network_id"
  type        = string
  sensitive   = true
}

variable "subnet_id" {
  description = "Yandex Cloud subnet_id"
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Yandex Cloud zone_id"
  type        = string
  sensitive   = true
}

variable "service_account_id" {
  description = "Yandex Cloud service_account_id"
  type        = string
  sensitive   = true
}

variable "node_service_account_id" {
  description = "Yandex Cloud node_service_account_id"
  type        = string
  sensitive   = true
}