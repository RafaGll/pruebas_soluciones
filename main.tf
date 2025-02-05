terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
      version = ">= 1.12.0"
    }
  }
}

# Configure the IBM Provider
provider "ibm" {
  region = "eu-es"
  ibmcloud_api_key=var.api_key
}



resource "ibm_is_vpc" "vpc_module_abermudez" {
  name = "vpc-abermudez"
  resource_group = var.resource_group

}

resource "ibm_is_subnet" "subnet_module_abermudez" {
  name = "subnet-abermudez"
  vpc = ibm_is_vpc.vpc_module_abermudez.id
  zone = "eu-es-1"
  ipv4_cidr_block = "10.251.10.0/24"
  resource_group  = var.resource_group  


}


resource "ibm_is_security_group" "ssh_abermudez_security_group" {
  name            = "ssh-security-group"
  vpc          =  ibm_is_vpc.vpc_module_abermudez.id
  resource_group  = var.resource_group  
}



resource "ibm_is_security_group_rule" "ssh_rule" {
  group     = ibm_is_security_group.ssh_abermudez_security_group.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}



resource "ibm_is_ssh_key" "ssh_key_abermudez" {
  name       = "ssh-key-abermudez"
  public_key = <<-EOF
 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQYePYr1IxSOGxJ6+lKuD4onsLK8jxU93BvYAB2lxTgomteXCpdHnKK3jix8hxadmANkG/k9kEjxWwKQR7ZVyw8eQul3aLCfMnHGqplVQH3JSsz5bKMaCNx8r2P5SYGLeTmbixZUmjlFxeacEQ7/8RPvVESZ5IvrOpNtsW0kF3IsxXZndLhZlC+a69xIw2UTDVYRjwSFcB4BLl2Z3YPIwcFNWyDQdThmSWJkfdXxOmunaVRVK+OFhEAJmIf8TJ6JVBbsBf1RU2khD8M3zGpxTKF6W0rb9seEkfHERhJbYpv8NmyWST8vgyCYRElKQK+IWmT4qMua+q6eXcrUtalyZa1m8rIytze10sa4kBsN/fdr/rtACDo+hx/e1lU5GnwodPscFaVHHH5nIOF1iq4llRevoPsTvSwViAE9Se1BrLZC1MrpyxF8l7LTDqCYbRuWoTXP5w5ElbqKIEbaBvv3xhd8V7jW0VYvg/vSbD9ZApAmb7QRnzzjGLCKS9k5/rOvhtcT/FP7XXxivnc+tRp7Q+FRjHAPgmhd9unk/LTUjXhaD9+M30nDol39jT+jwBZ8JOW1rFEFQJkGM7wfqSzbJRQutH5VMCX3XSk1+qv2hz5Sza1IJJPfeleetFRT9b1AbU/TCRpOg7ZwrcvMd9xyWFacHTqaUR2/oXF2c6FzT6FQ== abermudez@stemdo
  EOF
  resource_group = var.resource_group
  
}


resource "ibm_is_instance" "vm_abermudez" {
  name              = "vm-abermudez"
  vpc               = ibm_is_vpc.vpc_module_abermudez.id
  profile           = "bx2-2x8"
  zone              = "eu-es-1"
  keys = [ibm_is_ssh_key.ssh_key_abermudez.id]  
  image             = "r050-b98611da-e7d8-44db-8c42-2795071eec24"
  resource_group = var.resource_group

  primary_network_interface {
    subnet          = ibm_is_subnet.subnet_module_abermudez.id
    security_groups = [ibm_is_security_group.ssh_abermudez_security_group.id]

  }
}

resource "ibm_is_floating_ip" "public_ip" {
  name   = "public-ip-abermudez"
  target = ibm_is_instance.vm_abermudez.primary_network_interface[0].id
  resource_group = var.resource_group
  depends_on = [ibm_is_instance.vm_abermudez]

}
