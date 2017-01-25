terraform {
    required_version = "> 0.8.0"
}

# TODO: export envvar: TF_VAR_buildnum so we can use it inside here for things like VM name

variable "buildnum" {
    description = "Jenkins buildnum"
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

variable "vsphere_user" {
    default = "root"
}

variable "vsphere_pass" {
    default = "vmware"
}

variable "vsphere_server" {
    default = "10.193.231.56"
}

# ============================================
# VM
resource "vsphere_virtual_machine" "jenkins_netplugin" {
    count = "${var.num_nodes}"
    name = "Jenkins-Netplugin-${var.buildnum}-${count.index}"

    #folder = "${var.folder_name}"

    #linked_clone = true

    vcpu = "${var.cpus}"
    memory = "${var.mem}"

    datacenter = "${var.this_datacenter}"

    disk {
        template = "${var.disk_template}"
    }

    # control network interface, uses DHCP, so don't need to specify other network values
    network_interface {
        label = "${var.control_network}"
    }

#    # virtual network, uses static IP
#    network_interface {
#        label = "${var.virt_network}"
#        ipv4_address = "${var.virt_network_address}"
#        ipv4_prefix_length = "${var.virt_network_addr_length}" # subnet mask number of bits, eg. 24
#        ipv4_gateway = "${var.virt_network_gateway}"
#    }

}

# how many VM nodes to  create
variable "num_nodes" {
    default = "1"
}

###
# VM parameters

# use unique folder names, similar to the VM name.
variable "folder_name" {
    #default = "jenkins-folder-{var.buildnum}-${count.index}"
    default = "jenkins-folder"
}

variable "this_datacenter" {
    default = "aci-swarm-test"
}

variable "cpus" {
    default = "1"
}

variable "mem" {
    default = "2048"
} 

variable "control_network" {
    default = "VM Network"
}

#variable "virt_network" {
#    default = "that other network"
#}

# VM Template name
variable "disk_template" {
    default = "centos7-swarm-template-2017"
}
