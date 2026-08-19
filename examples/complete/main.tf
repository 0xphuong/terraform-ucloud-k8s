terraform {
  required_version = ">= 1.3.0"
  required_providers {
    ucloud = {
      source  = "ucloud/ucloud"
      version = ">= 1.39.5"
    }
  }
}

variable "password" {
  type      = string
  sensitive = true
}

variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "app_subnet_id" { type = string }

data "ucloud_zones" "default" {}

# Several node groups off one cluster: each group is its own shape, and adding
# or resizing a group never touches the others.
module "k8s" {
  source = "../../"

  password = var.password

  cluster = {
    name         = "uk8s-complete"
    vpc_id       = var.vpc_id
    subnet_id    = var.subnet_id
    service_cidr = "172.16.0.0/16"

    k8s_version                = "1.27.3"
    charge_type                = "dynamic"
    enable_external_api_server = true
    kube_proxy_mode            = "ipvs"
    delete_disks_with_instance = true

    master = {
      availability_zones = [
        data.ucloud_zones.default.zones[0].id,
        data.ucloud_zones.default.zones[1].id,
        data.ucloud_zones.default.zones[2].id,
      ]
      instance_type  = "n-basic-4"
      boot_disk_type = "cloud_ssd"
    }

    timeouts = {
      create = "40m"
    }
  }

  node_groups = {
    # General workloads.
    general = {
      desired_size      = 3
      instance_type     = "n-basic-4"
      availability_zone = data.ucloud_zones.default.zones[0].id
      boot_disk_type    = "cloud_ssd"
      data_disk_type    = "cloud_ssd"
      data_disk_size    = 100
    }

    # Memory-heavy workloads, on their own subnet and with its own password.
    memory = {
      desired_size      = 2
      instance_type     = "n-highmem-8"
      availability_zone = data.ucloud_zones.default.zones[1].id
      subnet_id         = var.app_subnet_id
      password          = var.password
      min_cpu_platform  = "Intel/Cascadelake"
    }

    # Created unschedulable so a DaemonSet can be staged before workloads land.
    batch = {
      desired_size               = 2
      instance_type              = "n-basic-2"
      availability_zone          = data.ucloud_zones.default.zones[0].id
      disable_schedule_on_create = true
    }

    # Kept in code but not provisioned. Flip to true to bring it up.
    gpu = {
      enabled           = false
      desired_size      = 1
      instance_type     = "n-basic-2"
      availability_zone = data.ucloud_zones.default.zones[0].id
    }
  }
}

output "external_api_server" {
  value = module.k8s.external_api_server
}

output "nodes_by_group" {
  value = module.k8s.node_group_names
}

output "node_private_ips" {
  value = module.k8s.node_private_ips
}
