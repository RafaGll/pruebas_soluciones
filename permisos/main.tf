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
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Esperando a que el cluster 'ibm-openshift-pruebas' esté completamente desplegado..."
      while true; do
        # Obtener la salida del cluster
        output=$(ibmcloud ks cluster get --cluster ibm-openshift-pruebas --output json 2>/dev/null)
        state=$(echo "$output" | jq -r '.state')
        master_url=$(echo "$output" | jq -r '.master_url')
        echo "DEBUG: Estado: '$state', master_url: '$master_url'"
        
        # Intentar obtener la configuración del cluster con el comando de la CLI.
        ibmcloud ks cluster config --cluster ibm-openshift-pruebas --output json >/dev/null 2>&1
        config_result=$?
        echo "DEBUG: Resultado de 'ibmcloud ks cluster config': $config_result"
        
        # Si el estado es normal, master_url tiene valor y el comando para obtener la configuración tuvo éxito, salimos.
        if [ "$state" = "normal" ] && [ -n "$master_url" ] && [ "$master_url" != "null" ] && [ $config_result -eq 0 ]; then
          echo "El cluster está completamente desplegado y la configuración está disponible."
          exit 0
        fi
        echo "El cluster aún no está listo. Esperando 10 segundos..."
        sleep 10
      done
    EOT
  }
}



data "ibm_resource_group" "resource_group" {
  depends_on = [ null_resource.wait_for_cluster ]
  name = var.resource_group
}

data "ibm_container_vpc_cluster" "cluster" {
  depends_on = [ null_resource.wait_for_cluster ]
  name = "ibm-openshift-pruebas"
  resource_group_id = data.ibm_resource_group.resource_group.id
}
data "ibm_container_cluster_config" "cluster_config" {
  depends_on = [ null_resource.wait_for_cluster ]
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
  depends_on = [ null_resource.wait_for_cluster ]
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
