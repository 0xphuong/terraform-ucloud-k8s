terraform {
  required_version = ">= 1.3.0"

  required_providers {
    ucloud = {
      source  = "ucloud/ucloud"
      version = ">= 1.39.5"
    }
  }
}
