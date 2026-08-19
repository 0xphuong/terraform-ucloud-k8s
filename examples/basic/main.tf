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

data "ucloud_zones" "default" {}

resource "ucloud_vpc" "this" {
  name        = "uk8s-basic"
  tag         = "uk8s"
  cidr_blocks = ["192.168.0.0/16"]
}

resource "ucloud_subnet" "this" {
  name       = "uk8s-basic"
  tag        = "uk8s"
  cidr_block = "192.168.1.0/24"
  vpc_id     = ucloud_vpc.this.id
}

module "k8s" {
  source = "../../"

  password = var.password

  cluster = {
    name         = "uk8s-basic"
    vpc_id       = ucloud_vpc.this.id
    subnet_id    = ucloud_subnet.this.id
    service_cidr = "172.16.0.0/16"
    charge_type  = "dynamic"

    master = {
      # Three entries create three masters. Repeat one zone for a single-AZ
      # control plane, or list distinct zones to spread it.
      availability_zones = [
        data.ucloud_zones.default.zones[0].id,
        data.ucloud_zones.default.zones[0].id,
        data.ucloud_zones.default.zones[0].id,
      ]
      instance_type = "n-basic-2"
    }
  }

  node_groups = {
    default = {
      desired_size      = 2
      instance_type     = "n-basic-2"
      availability_zone = data.ucloud_zones.default.zones[0].id
    }
  }
}

output "api_server" {
  value = module.k8s.api_server
}

output "node_ids" {
  value = module.k8s.node_ids
}
