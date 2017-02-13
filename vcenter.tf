# Sample terraform script to create VMs on vcenter cluster for use with Contiv
#
# To use:
# 1. Create vcenter.tfvars file with the following variables defined
# 2. Place this file (vcenter.tf) and your new vcenter.tfvars in the same
#    directory.
# 3. Test your terraform configuration:
#    $ terraform plan -var-file vcenter.tfvars
#
# 4. If no errors, bring up your terraform environment:
#    $ terraform apply -var-file vcenter.tfvars

# ============================================
# vcenter.tfvars template
# Provide connection information for vCenter server.
# THIS INFO NEEDS TO BE REDACTED BEFORE GOING TO A REPO.
# vsphere_user = "xxxxx"
#
# vsphere_pass = "xxxxx"
#
# vsphere_server = "xxxxx"
#
# devuser  = "xxxxx"
#
# number of nodes to build
# num_nodes = "3"
#
# Assigned VMgroup Number
# group_num = "xxxxx"
# folder_name = "xxxxx"
#
# network settings
# net1 / control network
#control_network_name = "VM Network"
#
# assign other networks for l2,l3 or ACI (if needed)
# net2_network = "xxxxx"
# 
# net3_network = "xxxxx"
#
# net4_network = "xxxxx"
# ============================================
# ============================================
# ============================================

# vcenter.tf script
terraform {
    required_version = "> 0.8.0"
}

# ============================================
# external variables
variable "buildnum" {
    default = "000"
}


# ============================================
# Authentication
provider "vsphere" {
    user           = "${var.vsphere_user}"
    password       = "${var.vsphere_pass}"
    vsphere_server = "${var.vsphere_server}"
    allow_unverified_ssl = true
}

# defined in vcenter.tfvars
variable "vsphere_user" {}
variable "vsphere_pass" {}
variable "vsphere_server" {}

# ============================================
# VM 
resource "vsphere_virtual_machine" "contiv_dev" {
    count = "${var.num_nodes}"
    name = "${var.devuser}-${var.buildnum}-vm-${count.index + 1}"


    folder = "${var.folder_name}"

    # specify the vm, not template if you use linked_clone
    linked_clone = true

    vcpu = "${var.cpus}"
    memory = "${var.mem}"

    datacenter = "${var.this_datacenter}"
    cluster = "${var.this_cluster}"

    # specify the template to use, and where to put it.
    disk {
        template = "${var.disk_template}"
        datastore = "${var.datastore_name}"
    }


    dns_suffixes = ["cisco.com"]
    dns_servers = ["171.70.168.183","173.36.131.10"]
	

    # control network interface, 
    # if you don't specify the address/netmask/gateway, dhcp is assumed

    # net1 interface - public IP
    network_interface {
        label = "${var.control_network_name}"
#        ipv4_address = "${var.control_network_ip[count.index]}"
#        ipv4_prefix_length = "${var.control_network_netmask}"
#        ipv4_gateway = "${var.control_network_gateway}"

    }

    # "layer 2" network 
    # net2 interface
    network_interface {
        label = "${var.net2_network}"
    }

    # "layer 3" network
    # virtual network, uses static IP
    network_interface {
        label = "${var.net3_network}"
    }

    # "ACI" network
    # virtual network, uses static IP
    network_interface {
        label = "${var.net4_network}"
    }

}

# defined in vcenter.tfvars
variable "devuser" {}
variable "num_nodes" {}
variable "group_num" {}

variable "control_network_name" {}
#variable "control_network_ip" {}
#variable "control_network_netmask" {}

variable "net2_network" {}
variable "net3_network" {}
variable "net4_network" {}

variable "cpus" {
    default = "3"
}

variable "mem" {
    default = "16384"
}

# ============================================
# vsphere parameters

variable "folder_name" {
# can't do this - terraform is lame
#    default = "VMgroup/$${var.group_num}"
    default = "VMgroup/101"
}

variable "this_datacenter" {
    default = "Lab1"
}

variable "this_cluster" {
    default = "ClusterOne"
}

variable "datastore_name" {
    default = "VMdatastore4"
}


# VM Template name
variable "disk_template" {
    # use this if not creating linked clones
#    default = "VMgroup/contiv-vm-template"
    # use this if creating linked clones
    default = "VMgroup/contiv-vm-clone"
}

# ============================================
output "public_ip_addresses" {
    value = ["${vsphere_virtual_machine.contiv_dev.*.network_interface.0.ipv4_address}"]
}
