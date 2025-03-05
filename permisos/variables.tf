# IBM provider variables
# uncomment if using local terraform
variable "ibmcloud_api_key" {
  description = "IBM api key"
  type        = string
}

# Global variables
variable "cluster_name" {
  type        = string
  default     = "cluster-pruebas"
  description = "The name used for creating the VPC, cluster, and other resources. The name will be appended by a random 4 digit string."
}

variable "namespace_name" {
  type        = string
  default     = "stemdo-wiki"
  description = "The name used for creating the namespace in the cluster."
}

variable "access_group_name" {
  type        = string
  default     = "STEMDO_Wiki"
  description = "The name of the access group."
}

variable "region" {
  type        = string
  default     = "eu-es"
  description = "The region to deploy the resources to."
}

variable "resource_group" {
  type        = string
  default     = "Stemdo_Sandbox"
  description = "The resource group to deploy the resources to."
}