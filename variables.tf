# A validation block may only reference its own variable before Terraform 1.9,
# and this module supports >= 1.3.0 — so nothing here cross-checks `cluster`
# against `node_groups`. Those relationships are enforced in main.tf instead.

variable "password" {
  description = "Default password for the cluster masters and every node. 8-30 characters with at least 2 of: capitals, lower case, digits, special characters. A node group may override it."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.password) >= 8 && length(var.password) <= 30
    error_message = "password must be between 8 and 30 characters."
  }
}

variable "cluster" {
  description = "Cluster-level configuration. `master` sizes the control plane; its availability_zones list also decides how many master nodes are created."
  type = object({
    name         = string
    vpc_id       = string
    subnet_id    = string
    service_cidr = string

    k8s_version                = optional(string)
    image_id                   = optional(string)
    charge_type                = optional(string, "dynamic")
    duration                   = optional(number)
    enable_external_api_server = optional(bool)
    delete_disks_with_instance = optional(bool, true)
    user_data                  = optional(string)
    init_script                = optional(string)

    # Rendered as the kube_proxy block when set. "ipvs" or "iptables".
    kube_proxy_mode = optional(string)

    master = object({
      availability_zones = list(string)
      instance_type      = string
      boot_disk_type     = optional(string)
      data_disk_type     = optional(string)
      data_disk_size     = optional(number)
      min_cpu_platform   = optional(string)
    })

    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  })

  validation {
    condition     = can(cidrhost(var.cluster.service_cidr, 0))
    error_message = "cluster.service_cidr must be a valid IPv4 CIDR block."
  }
  validation {
    condition     = length(var.cluster.name) >= 1 && length(var.cluster.name) <= 63
    error_message = "cluster.name must be between 1 and 63 characters."
  }
  validation {
    condition     = contains(["year", "month", "dynamic"], var.cluster.charge_type)
    error_message = "cluster.charge_type must be 'year', 'month', or 'dynamic'."
  }
  # Nested conditionals, not `||`: HCL evaluates every operand of `||`, so a
  # null duration would blow up the comparison even when the first test passes.
  validation {
    condition = var.cluster.charge_type == "dynamic" ? true : (
      var.cluster.duration == null ? true : var.cluster.duration >= 0
    )
    error_message = "cluster.duration must be >= 0 when charge_type is 'month' or 'year'."
  }
  validation {
    condition     = length(var.cluster.master.availability_zones) > 0
    error_message = "cluster.master.availability_zones must list at least one zone."
  }
  validation {
    condition = var.cluster.master.boot_disk_type == null ? true : contains(
      ["local_normal", "local_ssd", "cloud_ssd", "rssd_data_disk"], var.cluster.master.boot_disk_type
    )
    error_message = "cluster.master.boot_disk_type must be one of: local_normal, local_ssd, cloud_ssd, rssd_data_disk."
  }
  validation {
    condition     = var.cluster.master.data_disk_size == null ? true : var.cluster.master.data_disk_size % 10 == 0
    error_message = "cluster.master.data_disk_size must be a multiple of 10 GB."
  }
  validation {
    condition = var.cluster.kube_proxy_mode == null ? true : contains(
      ["ipvs", "iptables"], var.cluster.kube_proxy_mode
    )
    error_message = "cluster.kube_proxy_mode must be 'ipvs' or 'iptables'."
  }
}

variable "node_groups" {
  description = "Worker node groups, keyed by group name. Each group creates `desired_size` identical nodes named <group>-<index>. Unset fields fall back to the cluster or to var.password."
  type = map(object({
    enabled           = optional(bool, true)
    desired_size      = number
    instance_type     = string
    availability_zone = string

    # Fall back to the cluster / var.password when null.
    password    = optional(string)
    subnet_id   = optional(string)
    charge_type = optional(string)
    duration    = optional(number)
    image_id    = optional(string)

    boot_disk_type   = optional(string)
    data_disk_type   = optional(string)
    data_disk_size   = optional(number)
    min_cpu_platform = optional(string)

    isolation_group            = optional(string)
    user_data                  = optional(string)
    init_script                = optional(string)
    delete_disks_with_instance = optional(bool, true)
    disable_schedule_on_create = optional(bool)

    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for k, g in var.node_groups : g.enabled ? g.desired_size >= 1 : true])
    error_message = "Each enabled node group must have desired_size >= 1."
  }
  validation {
    condition = alltrue([
      for k, g in var.node_groups :
      g.charge_type == null ? true : contains(["year", "month", "dynamic"], g.charge_type)
    ])
    error_message = "node_groups[*].charge_type must be 'year', 'month', or 'dynamic'."
  }
  validation {
    condition = alltrue([
      for k, g in var.node_groups :
      g.boot_disk_type == null ? true : contains(["local_normal", "local_ssd", "cloud_ssd", "cloud_rssd"], g.boot_disk_type)
    ])
    error_message = "node_groups[*].boot_disk_type must be one of: local_normal, local_ssd, cloud_ssd, cloud_rssd."
  }
  validation {
    condition = alltrue([
      for k, g in var.node_groups :
      g.data_disk_type == null ? true : contains(["local_normal", "local_ssd", "cloud_ssd", "cloud_rssd"], g.data_disk_type)
    ])
    error_message = "node_groups[*].data_disk_type must be one of: local_normal, local_ssd, cloud_ssd, cloud_rssd."
  }
  validation {
    condition = alltrue([
      for k, g in var.node_groups :
      g.data_disk_size == null ? true : g.data_disk_size % 10 == 0
    ])
    error_message = "node_groups[*].data_disk_size must be a multiple of 10 GB."
  }
  validation {
    condition = alltrue([
      for k, g in var.node_groups :
      g.password == null ? true : (length(g.password) >= 8 && length(g.password) <= 30)
    ])
    error_message = "node_groups[*].password must be between 8 and 30 characters."
  }
}
