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
  ibmcloud_api_key = var.api_key
}

# VPC (reutilizada del ejercicio 5)
resource "ibm_is_vpc" "vpc_module_rgonzalez" {
  name = "vpc-rgonzalez"
  resource_group = var.resource_group
}

# Subredes en dos zonas distintas (modificado para ejercicio 6)
resource "ibm_is_subnet" "subnet_1" {
  name            = "subnet-rgonzalez-zona1"
  vpc             = ibm_is_vpc.vpc_module_rgonzalez.id
  zone            = "eu-es-1"
  # ipv4_cidr_block = "10.251.10.0/24"
  total_ipv4_address_count = 256  # Ampliado para permitir más direcciones
  resource_group  = var.resource_group
  # network_acl = ibm_is_network_acl.acl.id 
}

resource "ibm_is_subnet" "subnet_2" {
  name            = "subnet-rgonzalez-zona2"
  vpc             = ibm_is_vpc.vpc_module_rgonzalez.id
  zone            = "eu-es-2"  # Nueva zona
  # ipv4_cidr_block = "10.251.20.0/24"  # Nuevo rango
  total_ipv4_address_count = 256  # Ampliado para permitir más direcciones
  resource_group  = var.resource_group
}

# Puertas de enlace públicas (nuevo para ejercicio 6)
resource "ibm_is_public_gateway" "pgw_1" {
  name           = "pgw-zona1"
  vpc            = ibm_is_vpc.vpc_module_rgonzalez.id
  resource_group = var.resource_group
  zone           = "eu-es-1"
}

resource "ibm_is_public_gateway" "pgw_2" {
  name           = "pgw-zona2"
  vpc            = ibm_is_vpc.vpc_module_rgonzalez.id
  resource_group = var.resource_group
  zone           = "eu-es-2"
}

# Asociación de puertas de enlace a subredes
resource "ibm_is_subnet_public_gateway_attachment" "pg_attach1" {
  subnet         = ibm_is_subnet.subnet_1.id
  public_gateway = ibm_is_public_gateway.pgw_1.id
}

resource "ibm_is_subnet_public_gateway_attachment" "pg_attach2" {
  subnet         = ibm_is_subnet.subnet_2.id
  public_gateway = ibm_is_public_gateway.pgw_2.id
}

# Security Group (ampliado para permitir HTTP)
resource "ibm_is_security_group" "sg_web" {
  name           = "sg-web-rgonzalez"
  vpc            = ibm_is_vpc.vpc_module_rgonzalez.id
  resource_group = var.resource_group
}

resource "ibm_is_security_group_rule" "ssh" {
  group     = ibm_is_security_group.sg_web.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "http" {
  group     = ibm_is_security_group.sg_web.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 80
    port_max = 80
  }
}

# Agregar estas reglas al security group
resource "ibm_is_security_group_rule" "outbound_all" {
  group     = ibm_is_security_group.sg_web.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "icmp" {
  group     = ibm_is_security_group.sg_web.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  icmp {
    type = 8
  }
}

# SSH Key (reutilizada del ejercicio 5)
resource "ibm_is_ssh_key" "ssh_key_rgonzalez" {
  name       = "ssh-key-rgonzalez"
  public_key = <<-EOF
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCU94A3wzNYKAAYrOgQ6OGPcLVNYb73+FF5r/Vp/upSghDbdRzW95xm4BBTqaR+8Dm81UFycPjJlYnUaKYlrjGpTxKLoX6myC/RA0ddYH9WAD6ZRqdXepELdoikiZyvMOaMgOT5t6t9z9tWCuzkgvc5L8goYfHXzP44iGrkqR3Vf0Q3PmnHedFFFShbcT3p1vKR/9Z7VFF2my0Weg0C7tpE7VRBQ1dFlhzKCbAhWQ9SqZUowlh7/ASGzgX9K9czV6MtvE932YudPlSKrpD1GRejY+sndAfl1yOObyvKkUXmMjoqWIsRV3QBJtTNJNQk09MHMmwNEvTlW7T+ffe3Asqz
  EOF
  resource_group = var.resource_group
}

# Máquinas virtuales en ambas zonas
resource "ibm_is_instance" "vm1" {
  name           = "vm-rgonzalez-zona1"
  vpc            = ibm_is_vpc.vpc_module_rgonzalez.id
  profile        = "bx2-2x8"
  zone           = "eu-es-1"
  keys           = [ibm_is_ssh_key.ssh_key_rgonzalez.id]
  image          = "r050-b98611da-e7d8-44db-8c42-2795071eec24"
  resource_group = var.resource_group

  primary_network_interface {
    subnet          = ibm_is_subnet.subnet_1.id
    security_groups = [ibm_is_security_group.sg_web.id]
  }
}

resource "ibm_is_instance" "vm2" {
  name           = "vm-rgonzalez-zona2"
  vpc            = ibm_is_vpc.vpc_module_rgonzalez.id
  profile        = "bx2-2x8"
  zone           = "eu-es-2"
  keys           = [ibm_is_ssh_key.ssh_key_rgonzalez.id]
  image          = "r050-b98611da-e7d8-44db-8c42-2795071eec24"
  resource_group = var.resource_group

  primary_network_interface {
    subnet          = ibm_is_subnet.subnet_2.id
    security_groups = [ibm_is_security_group.sg_web.id]
  }
}

# IPs públicas para ambas VMs
resource "ibm_is_floating_ip" "ip_vm1" {
  name   = "ip-vm1-rgonzalez"
  target = ibm_is_instance.vm1.primary_network_interface[0].id
  resource_group = var.resource_group
}

resource "ibm_is_floating_ip" "ip_vm2" {
  name   = "ip-vm2-rgonzalez"
  target = ibm_is_instance.vm2.primary_network_interface[0].id
  resource_group = var.resource_group
}

# Balanceador de carga (nuevo para ejercicio 6)
resource "ibm_is_lb" "lb_web" {
  name           = "lb-web-rgonzalez"
  type           = "public"
  subnets        = [ibm_is_subnet.subnet_1.id, ibm_is_subnet.subnet_2.id]
  security_groups = [ibm_is_security_group.sg_web.id]
  resource_group = var.resource_group
}

resource "ibm_is_lb_pool" "pool_web" {
  name           = "pool-web-rgonzalez"
  lb             = ibm_is_lb.lb_web.id
  algorithm      = "round_robin"
  protocol       = "http"
  health_delay   = 5
  health_retries = 2
  health_timeout = 2
  health_type = "http"
}

resource "ibm_is_lb_listener" "http" {
  lb           = ibm_is_lb.lb_web.id
  port         = 80
  protocol     = "http"
  default_pool = ibm_is_lb_pool.pool_web.pool_id
}

resource "ibm_is_lb_pool_member" "member1" {
  lb             = ibm_is_lb.lb_web.id
  pool           = ibm_is_lb_pool.pool_web.pool_id
  port           = 80
  target_address = ibm_is_instance.vm1.primary_network_interface[0].primary_ipv4_address
}

resource "ibm_is_lb_pool_member" "member2" {
  lb             = ibm_is_lb.lb_web.id
  pool           = ibm_is_lb_pool.pool_web.pool_id
  port           = 80
  target_address = ibm_is_instance.vm2.primary_network_interface[0].primary_ipv4_address
}

# Outputs para acceso
output "ip_balanceador" {
  value = ibm_is_lb.lb_web.hostname
}

output "ip_publica_vm1" {
  value = ibm_is_floating_ip.ip_vm1.address
}

output "ip_publica_vm2" {
  value = ibm_is_floating_ip.ip_vm2.address
}