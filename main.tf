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
  ibmcloud_api_key=var.api_key
}

resource "ibm_is_vpc" "vpc_module_rgonzalez" {
  name = "vpc-rgonzalez"
  resource_group = var.resource_group
}

resource "ibm_is_subnet" "subnet_module_rgonzalez" {
  name = "subnet-rgonzalez"
  vpc = ibm_is_vpc.vpc_module_rgonzalez.id
  zone = "eu-es-1"
  ipv4_cidr_block = "10.251.10.0/24"
  resource_group  = var.resource_group  
}

# Puertas de enlace públicas (nuevo para ejercicio 6)
resource "ibm_is_public_gateway" "pgw" {
  name           = "pgw-zona1"
  vpc            = ibm_is_vpc.vpc_module_rgonzalez.id
  resource_group = var.resource_group
  zone           = "eu-es-1"
}

# Asociación de puertas de enlace a subredes
resource "ibm_is_subnet_public_gateway_attachment" "pg_attach1" {
  subnet         = ibm_is_subnet.subnet_module_rgonzalez.id
  public_gateway = ibm_is_public_gateway.pgw.id
}

resource "ibm_is_security_group" "ssh_rgonzalez_security_group" {
  name            = "ssh-security-group"
  vpc          =  ibm_is_vpc.vpc_module_rgonzalez.id
  resource_group  = var.resource_group  
}

resource "ibm_is_security_group_rule" "ssh_rule" {
  group     = ibm_is_security_group.ssh_rgonzalez_security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "http" {
  group     = ibm_is_security_group.ssh_rgonzalez_security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 80
    port_max = 80
  }
}
resource "ibm_is_security_group_rule" "icmp" {
  group     = ibm_is_security_group.ssh_rgonzalez_security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  icmp {
    type = 8
  }
}
resource "ibm_is_security_group_rule" "outbound_all" {
  group     = ibm_is_security_group.ssh_rgonzalez_security_group.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_ssh_key" "ssh_key_rgonzalez" {
  name       = "ssh-key-rgonzalez"
  public_key = <<-EOF
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCU94A3wzNYKAAYrOgQ6OGPcLVNYb73+FF5r/Vp/upSghDbdRzW95xm4BBTqaR+8Dm81UFycPjJlYnUaKYlrjGpTxKLoX6myC/RA0ddYH9WAD6ZRqdXepELdoikiZyvMOaMgOT5t6t9z9tWCuzkgvc5L8goYfHXzP44iGrkqR3Vf0Q3PmnHedFFFShbcT3p1vKR/9Z7VFF2my0Weg0C7tpE7VRBQ1dFlhzKCbAhWQ9SqZUowlh7/ASGzgX9K9czV6MtvE932YudPlSKrpD1GRejY+sndAfl1yOObyvKkUXmMjoqWIsRV3QBJtTNJNQk09MHMmwNEvTlW7T+ffe3Asqz
  EOF
  resource_group = var.resource_group
}

resource "ibm_is_instance" "vm_rgonzalez" {
  name              = "vm-rgonzalez"
  vpc               = ibm_is_vpc.vpc_module_rgonzalez.id
  profile           = "bx2-2x8"
  zone              = "eu-es-1"
  keys = [ibm_is_ssh_key.ssh_key_rgonzalez.id]
  image             = "r050-b98611da-e7d8-44db-8c42-2795071eec24"
  resource_group = var.resource_group

  primary_network_interface {
    subnet          = ibm_is_subnet.subnet_module_rgonzalez.id
    security_groups = [ibm_is_security_group.ssh_rgonzalez_security_group.id]
  }
}

resource "ibm_is_floating_ip" "public_ip" {
  name   = "public-ip-rgonzalez"
  target = ibm_is_instance.vm_rgonzalez.primary_network_interface[0].id
  resource_group = var.resource_group
  depends_on = [ibm_is_instance.vm_rgonzalez]
}