# Changelog

All notable changes to this module will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-08-17

### Added
- `ucloud_uk8s_cluster` provisioning through a single `cluster` object, including the `master` block,
  optional `kube_proxy` mode and per-resource `timeouts`
- `node_groups` map: EKS-style worker pools, each with its own size, instance type, zone, subnet, disks
  and password
- `desired_size` scaling with `<group>-<index>` keys, so growing a group adds nodes instead of replacing
  the existing ones
- `enabled = false` to park a node group without deleting its configuration
- Fallbacks from a node group to `cluster.subnet_id`, `cluster.charge_type` and `var.password`
- Outputs for cluster identity, API endpoints, pod/service CIDRs, and node IDs, statuses and IPs both flat
  and grouped by node group
- Validation of `service_cidr`, cluster name length, charge types, disk types, `data_disk_size` multiples
  of 10 GB, password length, and `desired_size >= 1` on enabled groups
- `examples/basic` and `examples/complete`

### Notes
- `charge_type` defaults to `dynamic` rather than the provider's `month`, so an accidental apply cannot
  commit to a month of billing
