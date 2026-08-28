variable "proxmox_api_endpoint" {
  description = "URL of the Proxmox VE API, e.g. https://pve.example.com:8006/api2/json"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form 'user@realm!token-id=uuid-secret'"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS certificate verification (true if using a self-signed cert)"
  type        = bool
  default     = false
}

variable "proxmox_ssh_username" {
  description = "SSH username used by the provider for node-level operations (file uploads, etc.)"
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Name of the Proxmox VE node to deploy resources on"
  type        = string
  default     = "one-main"
}

variable "template_vm_id" {
  description = "VM ID of the template to clone (template-ubuntu-24.04-15gb-salt-metrics)"
  type        = number
  default     = 147
}

variable "vm_datastore_id" {
  description = "Datastore to place cloned VM disks on"
  type        = string
  default     = "vm-data"
}

variable "vault_node_count" {
  description = "Number of Vault cluster nodes to create"
  type        = number
  default     = 3
}

variable "consul_node_count" {
  description = "Number of Consul cluster nodes to create"
  type        = number
  default     = 3
}

variable "cluster_bridge" {
  description = "Proxmox bridge for the Vault/Consul cluster nodes' NICs"
  type        = string
  default     = "hashibr"
}
