resource "yandex_kubernetes_node_group" "my_node_group" {
  cluster_id = yandex_kubernetes_cluster.momo-cluster.id
  name       = "nodegroup"
  version    = "1.20"


  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = [var.subnet_id]
    }

    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = var.zone_id
    }
  }

}