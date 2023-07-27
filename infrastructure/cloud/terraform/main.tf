terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

}

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone_id
}


resource "yandex_kubernetes_cluster" "momo-cluster" {
  name        = "momo-cluster"
  description = "momo-cluster description"

  network_id              = var.network_id
  service_account_id      = var.service_account_id
  node_service_account_id = var.node_service_account_id


  master {
    zonal {
      zone      = var.zone_id
      subnet_id = var.subnet_id
    }

    public_ip = true

    maintenance_policy {
      auto_upgrade = false
    }

  }


}

output "kubid" {
  value = yandex_kubernetes_cluster.momo-cluster.id
}