locals {
  # Expand every enabled node group into one entry per node. `desired_size` is
  # the group's node count; each node is keyed <group>-<index> so adding to a
  # group never re-creates the nodes already in it.
  expanded_nodes = flatten([
    for group_name, g in var.node_groups : g.enabled ? [
      for i in range(g.desired_size) : {
        key   = "${group_name}-${i}"
        group = group_name
        index = i

        instance_type     = g.instance_type
        availability_zone = g.availability_zone

        # Group value first, then the cluster-wide fallback.
        password    = g.password != null ? g.password : var.password
        subnet_id   = g.subnet_id != null ? g.subnet_id : var.cluster.subnet_id
        charge_type = g.charge_type != null ? g.charge_type : var.cluster.charge_type
        duration    = g.duration
        image_id    = g.image_id

        boot_disk_type   = g.boot_disk_type
        data_disk_type   = g.data_disk_type
        data_disk_size   = g.data_disk_size
        min_cpu_platform = g.min_cpu_platform

        isolation_group            = g.isolation_group
        user_data                  = g.user_data
        init_script                = g.init_script
        delete_disks_with_instance = g.delete_disks_with_instance
        disable_schedule_on_create = g.disable_schedule_on_create
        timeouts                   = g.timeouts
      }
    ] : []
  ])

  node_map = { for n in local.expanded_nodes : n.key => n }
}

resource "ucloud_uk8s_cluster" "this" {
  name         = var.cluster.name
  vpc_id       = var.cluster.vpc_id
  subnet_id    = var.cluster.subnet_id
  service_cidr = var.cluster.service_cidr
  password     = var.password

  charge_type = var.cluster.charge_type
  duration    = var.cluster.charge_type != "dynamic" ? var.cluster.duration : null

  # Optional
  k8s_version                = var.cluster.k8s_version
  image_id                   = var.cluster.image_id
  enable_external_api_server = var.cluster.enable_external_api_server
  delete_disks_with_instance = var.cluster.delete_disks_with_instance
  user_data                  = var.cluster.user_data
  init_script                = var.cluster.init_script

  master {
    availability_zones = var.cluster.master.availability_zones
    instance_type      = var.cluster.master.instance_type

    boot_disk_type   = var.cluster.master.boot_disk_type
    data_disk_type   = var.cluster.master.data_disk_type
    data_disk_size   = var.cluster.master.data_disk_size
    min_cpu_platform = var.cluster.master.min_cpu_platform
  }

  dynamic "kube_proxy" {
    for_each = var.cluster.kube_proxy_mode != null ? [var.cluster.kube_proxy_mode] : []
    content {
      mode = kube_proxy.value
    }
  }

  dynamic "timeouts" {
    for_each = var.cluster.timeouts != null ? [var.cluster.timeouts] : []
    content {
      create = timeouts.value.create
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "ucloud_uk8s_node" "this" {
  for_each = local.node_map

  cluster_id        = ucloud_uk8s_cluster.this.id
  availability_zone = each.value.availability_zone
  instance_type     = each.value.instance_type
  password          = each.value.password

  charge_type = each.value.charge_type
  duration    = each.value.charge_type != "dynamic" ? each.value.duration : null

  # Optional
  subnet_id                  = each.value.subnet_id
  image_id                   = each.value.image_id
  boot_disk_type             = each.value.boot_disk_type
  data_disk_type             = each.value.data_disk_type
  data_disk_size             = each.value.data_disk_size
  min_cpu_platform           = each.value.min_cpu_platform
  isolation_group            = each.value.isolation_group
  user_data                  = each.value.user_data
  init_script                = each.value.init_script
  delete_disks_with_instance = each.value.delete_disks_with_instance
  disable_schedule_on_create = each.value.disable_schedule_on_create

  dynamic "timeouts" {
    for_each = each.value.timeouts != null ? [each.value.timeouts] : []
    content {
      create = timeouts.value.create
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
