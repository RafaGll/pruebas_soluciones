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



data "ibm_iam_access_group" "wiki" {
  access_group_name = "Stemdo_TEST"
}

resource "ibm_iam_access_group_policy" "containers" {
  depends_on = [ data.ibm_iam_access_group.wiki ]
  access_group_id = data.ibm_iam_access_group.wiki.groups[0].id
  roles           = ["Viewer"] 
  resource_attributes {
    value = "containers-kubernetes"
    name = "serviceName"
  }
}

resource "ibm_iam_access_group_policy" "vpc" {
  depends_on = [ ibm_iam_access_group_policy.containers ]
  access_group_id = data.ibm_iam_access_group.wiki.groups[0].id
  roles           = ["Viewer"] 
  resource_attributes {
    value = "is"
    name = "serviceName"
  }
}