# terraform-ucloud-k8s

Terraform module to provision a **UK8S cluster and its worker node groups** on [UCloud](https://www.ucloud.cn).

The interface follows the EKS shape: one `cluster` object for the control plane, and a `node_groups` map
where each entry is an independently sized, independently shaped pool of workers.

## Features

- One cluster plus any number of node groups from a single module call
- Per-group `instance_type`, zone, disks, subnet and password — groups are independent
- `desired_size` scales a group; node keys are `<group>-<index>`, so growing a group **adds** nodes and
  never re-creates the existing ones
- `enabled = false` parks a group in code without provisioning it
- Group values fall back to the cluster (`subnet_id`, `charge_type`) and to `var.password`
- Optional `kube_proxy` mode and per-resource `timeouts`
- Structured outputs, including node IDs and IPs grouped by node group

## Usage

### Basic

```hcl
module "k8s" {
  source = "github.com/0xphuong/terraform-ucloud-k8s?ref=v1.0.0"

  password = var.password

  cluster = {
    name         = "prod"
    vpc_id       = var.vpc_id
    subnet_id    = var.subnet_id
    service_cidr = "172.16.0.0/16"
    charge_type  = "dynamic"

    master = {
      availability_zones = ["sg-01", "sg-01", "sg-01"]
      instance_type      = "n-basic-2"
    }
  }

  node_groups = {
    default = {
      desired_size      = 2
      instance_type     = "n-basic-2"
      availability_zone = "sg-01"
    }
  }
}
```

### Several node groups

Each key is a pool. They share the cluster but nothing else, so a group can sit in its own zone or subnet,
run a different instance type, or carry its own disks.

```hcl
node_groups = {
  general = {
    desired_size      = 3
    instance_type     = "n-basic-4"
    availability_zone = "sg-01"
    data_disk_type    = "cloud_ssd"
    data_disk_size    = 100
  }

  memory = {
    desired_size      = 2
    instance_type     = "n-highmem-8"
    availability_zone = "sg-02"
    subnet_id         = var.app_subnet_id
  }

  batch = {
    desired_size               = 2
    instance_type              = "n-basic-2"
    availability_zone          = "sg-01"
    disable_schedule_on_create = true
  }
}
```

### Scaling a group

Change `desired_size`. Nodes are keyed `<group>-<index>`, so raising `general` from 3 to 4 plans exactly one
addition and leaves `general-0..2` untouched.

Lowering it removes the highest indexes. Nothing here reschedules pods — drain the node first.

### Parking a group

```hcl
gpu = {
  enabled           = false   # destroys the group's nodes, keeps the config
  desired_size      = 1
  instance_type     = "n-basic-2"
  availability_zone = "sg-01"
}
```

## Master count

`cluster.master.availability_zones` decides both placement **and** how many masters exist — three entries
create three masters. Repeat one zone for a single-AZ control plane, or list distinct zones to spread it.

## Inputs

| Name | Description | Type | Required |
|---|---|---|:--:|
| `password` | Default password for masters and nodes, 8–30 chars | `string` (sensitive) | yes |
| `cluster` | Control-plane configuration (see below) | `object` | yes |
| `node_groups` | Worker pools, keyed by group name | `map(object)` | no (`{}`) |

### `cluster`

| Field | Description | Default |
|---|---|---|
| `name` | Cluster name, 1–63 chars | — |
| `vpc_id`, `subnet_id` | Where the cluster lives | — |
| `service_cidr` | CIDR of the k8s service network | — |
| `master.availability_zones` | One entry per master | — |
| `master.instance_type` | Master instance type | — |
| `master.boot_disk_type` / `data_disk_type` / `data_disk_size` / `min_cpu_platform` | Master sizing | `null` |
| `k8s_version`, `image_id` | Pinned versions | `null` |
| `charge_type` | `year`, `month`, or `dynamic` | `"dynamic"` |
| `duration` | Billing periods; ignored when `dynamic` | `null` |
| `enable_external_api_server` | Expose the API server publicly | `null` |
| `delete_disks_with_instance` | Destroy cloud data disks with the node | `true` |
| `kube_proxy_mode` | `ipvs` or `iptables` | `null` |
| `user_data`, `init_script` | Startup customisation | `null` |
| `timeouts` | `create` / `update` / `delete` | `null` |

### `node_groups[*]`

| Field | Description | Default |
|---|---|---|
| `desired_size` | Nodes in the group | — |
| `instance_type` | Node instance type | — |
| `availability_zone` | Node zone | — |
| `enabled` | `false` parks the group | `true` |
| `password` | Overrides `var.password` | cluster-wide |
| `subnet_id` | Overrides `cluster.subnet_id` | cluster's |
| `charge_type` | Overrides `cluster.charge_type` | cluster's |
| `image_id`, `duration` | | `null` |
| `boot_disk_type`, `data_disk_type`, `data_disk_size` | Disks | `null` |
| `min_cpu_platform`, `isolation_group` | Placement | `null` |
| `user_data`, `init_script` | Startup customisation | `null` |
| `delete_disks_with_instance` | | `true` |
| `disable_schedule_on_create` | Create the node unschedulable | `null` |
| `timeouts` | `create` / `update` / `delete` | `null` |

## Outputs

| Name | Description |
|---|---|
| `cluster_id`, `cluster_name`, `cluster_status`, `cluster_create_time` | Cluster identity and state |
| `api_server` | In-cluster API endpoint |
| `external_api_server` | Public API endpoint (needs `enable_external_api_server`) |
| `pod_cidr`, `service_cidr` | Cluster networking |
| `node_ids`, `node_statuses` | Map of `<group>-<index>` => value |
| `node_private_ips`, `node_public_ips` | Map of node key => IP |
| `node_group_names`, `node_group_ids` | Map of group => its node keys / IDs |

## Notes

- **Almost everything is `ForceNew`.** Changing `instance_type`, zone, disks or `service_cidr` replaces the
  resource rather than updating it. Check the plan before applying.
- **`charge_type` defaults to `dynamic`** here (pay per hour), not to the provider's `month`, so a stray
  apply cannot commit to a month of billing. Set it explicitly if you want a committed term.
- **Node scale-in is not drained.** Reducing `desired_size` deletes the highest-indexed nodes immediately.
- **`password` reaches the state file.** Keep state backed by a remote backend with encryption at rest.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3.0 |
| ucloud provider | >= 1.39.5 |

## License

MIT
