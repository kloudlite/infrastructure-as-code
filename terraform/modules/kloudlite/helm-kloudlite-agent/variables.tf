variable "ssh_params" {
  description = "SSH parameters for the VM"
  type        = object({
    public_ip   = string
    username    = string
    private_key = string
  })
}

variable "release_name" {
  description = "Name of the helm release"
  type        = string
}

variable "release_namespace" {
  description = "Namespace to install the helm release"
  type        = string
}

variable "kloudlite_release" {
  description = "Kloudlite release to deploy"
  type        = string
}

variable "kloudlite_account_name" {
  description = "Kloudlite account name"
  type        = string
}

variable "kloudlite_cluster_name" {
  description = "Kloudlite cluster name"
  type        = string
}

variable "kloudlite_cluster_token" {
  description = "Kloudlite cluster token"
  type        = string
}

variable "kloudlite_message_office_grpc_addr" {
  description = "Kloudlite message office gRPC address"
  type        = string
}

variable "kloudlite_dns_host" {
  description = "Kloudlite DNS host"
  type        = string
}

variable "cloudprovider_name" {
  description = "cloudprovider name"
  type        = string
}

variable "cloudprovider_region" {
  description = "cloudprovider region"
  type        = string
}

variable "k3s_agent_join_token" {
  description = "k3s agent join token"
  type        = string
}
