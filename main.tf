terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
      version = ">= 1.12.0"
    }
  }
}

provider "ibm" {
  region = "eu-es"
  ibmcloud_api_key=var.ibmcloud_api_key
}

locals {
  name = "${var.name}"
  index = length(data.ibm_container_cluster_versions.cluster_versions.valid_openshift_versions) - 2
}

# Create random string to append to name
resource "random_string" "id" {
  length  = 4
  special = false
  upper   = false
}

# Name of resource group
data "ibm_resource_group" "resource_group" {
  name = var.resource_group
}

# Virtual Private Cloud (VPC)
resource "ibm_is_vpc" "vpc" {
  name = local.name
  resource_group               = data.ibm_resource_group.resource_group.id
}

# Public gateway to allow connectivity outside of the VPC
resource "ibm_is_public_gateway" "gateway_subnet" {
  resource_group               = data.ibm_resource_group.resource_group.id
  count = var.number_of_zones
  name  = "${local.name}-publicgateway-${count.index + 1}"
  vpc   = ibm_is_vpc.vpc.id
  zone  = "${var.region}-${count.index + 1}"

  //User can configure timeouts
  timeouts {
    create = "90m"
  }
}

# VPC subnets. Uses default CIDR range
resource "ibm_is_subnet" "subnet" {
  resource_group               = data.ibm_resource_group.resource_group.id
  count                    = var.number_of_zones
  name                     = "${local.name}-subnet-${count.index + 1}"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = "${var.region}-${count.index + 1}"
  total_ipv4_address_count = 256
  public_gateway           = ibm_is_public_gateway.gateway_subnet[count.index].id
}

# List of available cluster versions in IBM Cloud
data "ibm_container_cluster_versions" "cluster_versions" {
}

# OpenShift cluster. Defaults to single zone. Version by default will take the 2nd to last in the list of the valid openshift versions given in the output of `ibmcloud oc versions`
resource "ibm_container_vpc_cluster" "cluster" {
  name                            = local.name
  vpc_id                          = ibm_is_vpc.vpc.id
  flavor                          = var.worker_flavor
  kube_version                    = (var.kube_version != null ? var.kube_version : "${data.ibm_container_cluster_versions.cluster_versions.valid_openshift_versions[local.index]}_openshift")
  worker_count                    = var.workers_per_zone
  disable_public_service_endpoint = var.public_service_endpoint_disabled
  disable_outbound_traffic_protection = var.disable_outbound_traffic_protection
  resource_group_id               = data.ibm_resource_group.resource_group.id
  cos_instance_crn                = ibm_resource_instance.cos_instance.id
  wait_till                       = "OneWorkerNodeReady"

  dynamic "zones" {
    for_each = ibm_is_subnet.subnet
    content {
      name      = zones.value.zone
      subnet_id = zones.value.id
    }
  }
}


# COS instance for cluster registry backup
resource "ibm_resource_instance" "cos_instance" {
  name     = local.name
  service  = var.service_offering
  plan     = var.plan
  location = "global"
  resource_group_id               = data.ibm_resource_group.resource_group.id
}

# data "ibm_iam_users" "usuario" {
#   email = "acajas@stemdo.io" 
# }

resource "ibm_iam_user_policy" "usuario_policy" {
  ibm_id = "acajas@stemdo.io"
  roles  = ["Reader", "Writer", "Manager", "Viewer"] 

  resources {
    service = "containers-kubernetes"
    resource_group_id = data.ibm_resource_group.resource_group.id
    resource_type = "serviceInstance"
    resource      = "cuvcrbfm0q6aec1v8j40"
  }
}

