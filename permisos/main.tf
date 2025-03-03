
data "ibm_resource_group" "resource_group" {
  name = var.resource_group
}

data "ibm_container_vpc_cluster" "cluster" {
  name = "ibm-openshift-pruebas"
  resource_group_id = data.ibm_resource_group.resource_group.id
}
data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id = data.ibm_container_vpc_cluster.cluster.id
  resource_group_id = data.ibm_resource_group.resource_group.id
  admin = true
}

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
  cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
}

resource "kubernetes_namespace" "stemdo-wiki" {
  depends_on = [ data.ibm_container_cluster_config.cluster_config ]
  metadata {
    name = "stemdo-wiki"
  }
}

data "ibm_iam_access_group" "wiki" {
  access_group_name = "STEMDO_Wiki"
}

resource "ibm_iam_access_group_policy" "group_policy_viewer" {
  depends_on = [ kubernetes_namespace.stemdo-wiki ]
  access_group_id = data.ibm_iam_access_group.wiki.groups[0].id
  roles           = ["Viewer"] 

  resource_attributes {
    value = "containers-kubernetes"
    name = "serviceName"
  }
  
  resource_attributes {
    value = data.ibm_container_vpc_cluster.cluster.id
    operator = "stringEquals"
    name = "serviceInstance"
  }
}

resource "ibm_iam_access_group_policy" "group_policy_filter" {
  depends_on = [ kubernetes_namespace.stemdo-wiki ]
  access_group_id = data.ibm_iam_access_group.wiki.groups[0].id
  roles           = ["Reader", "Writer" ] 

  resource_attributes {
    value = "containers-kubernetes"
    name = "serviceName"
  }
  
  resource_attributes {
    value = data.ibm_container_vpc_cluster.cluster.id
    operator = "stringEquals"
    name = "serviceInstance"
  }
  
  resource_attributes {
    value = kubernetes_namespace.stemdo-wiki.metadata[0].name
    operator = "stringEquals"
    name = "namespace"
  }
}


resource "ibm_iam_user_policy" "user_policy_viewer" {
  depends_on = [ kubernetes_namespace.stemdo-wiki ]
  ibm_id = "acajas@stemdo.io"
  roles  = ["Viewer"] 

  resource_attributes {
    value = "containers-kubernetes"
    name = "serviceName"
  }
  
  resource_attributes {
    value = data.ibm_container_vpc_cluster.cluster.id
    operator = "stringEquals"
    name = "serviceInstance"
  }
}

resource "ibm_iam_user_policy" "user_policy_filter" {
  depends_on = [ kubernetes_namespace.stemdo-wiki ]
  ibm_id = "acajas@stemdo.io"
  roles  = ["Reader", "Writer", "Manager"] 

  resource_attributes {
    value = "containers-kubernetes"
    name = "serviceName"
  }
  
  resource_attributes {
    value = data.ibm_container_vpc_cluster.cluster.id
    operator = "stringEquals"
    name = "serviceInstance"
  }

  resource_attributes {
    value = kubernetes_namespace.stemdo-wiki.metadata[0].name
    operator = "stringEquals"
    name = "namespace"
  }
}
