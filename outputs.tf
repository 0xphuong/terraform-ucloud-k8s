output "cluster_id" {
  description = "The ID of the UK8S cluster"
  value       = ucloud_uk8s_cluster.this.id
}

output "cluster_name" {
  description = "The name of the UK8S cluster"
  value       = ucloud_uk8s_cluster.this.name
}

output "cluster_status" {
  description = "Cluster status: RUNNING, CREATEFAILED, DELETEFAILED, ERROR or ABNORMAL"
  value       = ucloud_uk8s_cluster.this.status
}

output "api_server" {
  description = "In-cluster API server endpoint"
  value       = ucloud_uk8s_cluster.this.api_server
}

output "external_api_server" {
  description = "Externally reachable API server endpoint (empty unless cluster.enable_external_api_server is true)"
  value       = ucloud_uk8s_cluster.this.external_api_server
}

output "pod_cidr" {
  description = "CIDR block of the pod network, assigned by UCloud"
  value       = ucloud_uk8s_cluster.this.pod_cidr
}

output "service_cidr" {
  description = "CIDR block of the k8s service network"
  value       = ucloud_uk8s_cluster.this.service_cidr
}

output "cluster_create_time" {
  description = "Cluster creation time, RFC3339"
  value       = ucloud_uk8s_cluster.this.create_time
}

output "node_ids" {
  description = "Map of node key (<group>-<index>) => node ID"
  value       = { for k, n in ucloud_uk8s_node.this : k => n.id }
}

output "node_statuses" {
  description = "Map of node key => node status"
  value       = { for k, n in ucloud_uk8s_node.this : k => n.status }
}

output "node_private_ips" {
  description = "Map of node key => private IP"
  value = {
    for k, n in ucloud_uk8s_node.this : k =>
    try([for ip in n.ip_set : ip.ip if ip.internet_type == "Private"][0], null)
  }
}

output "node_public_ips" {
  description = "Map of node key => public IP (null when the node has none)"
  value = {
    for k, n in ucloud_uk8s_node.this : k =>
    try([for ip in n.ip_set : ip.ip if ip.internet_type != "Private"][0], null)
  }
}

output "node_group_names" {
  description = "Map of group name => list of node keys in that group. Groups with enabled = false are absent."
  value = {
    for group_name in distinct([for n in local.expanded_nodes : n.group]) :
    group_name => sort([for n in local.expanded_nodes : n.key if n.group == group_name])
  }
}

output "node_group_ids" {
  description = "Map of group name => list of node IDs in that group"
  value = {
    for group_name in distinct([for n in local.expanded_nodes : n.group]) :
    group_name => [
      for n in local.expanded_nodes : ucloud_uk8s_node.this[n.key].id if n.group == group_name
    ]
  }
}
