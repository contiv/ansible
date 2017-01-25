# Script to create 3 Centos-7 instances on AWS with 2 network interfaces
# suitable for use with Contiv.

# How to use:
# Create terraform.tfvars file and define with correct values for your setup:
# aws_access_key = "XXXXXXXXXXXXXXXXXX"
# aws_secret_key = "XXXXXXXXXXXXXXXXXX"
# ssh_keypair = "foo.pem"
# key_path = "/full/path/to/foo.pem"
# our_security_group_id "sg-XXXXX"
# our_vpc_id = "vpc-XXXXXXXX"

# terraform apply

terraform {
    required_version = "> 0.8.0"
}

# optional: 
# define buildnum to use for the "name" tag for instances, and subnet.
#
# Normally set by our CI build system (Jenkins)
#
# eg. buildnum=103, creates instances named:
# jenkins-netplugin-103-0
# jenkins-netplugin-103-1
# jenkins-netplugin-103-2
#
# makes it easy to spot and clean-up if something goes wrong

variable "buildnum" {
    description = "Jenkins buildnum"
    default = "007"
}

# ============================================
# Authentication
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region     = "${var.aws_region}"
}

# defined in terraform.tfvars
variable "aws_access_key" {}
variable "aws_secret_key" {}

# NOTE: keys can only be alphanumeric. no special characters (- _ +)
# while these are valid for AWS, Terraform barfs on them  (bug?)

variable "aws_region" {
    default = "us-west-1"
}

# ============================================
# EC2 Instance definition

resource "aws_instance" "jenkins_netplugin" {
    ami           = "${var.aws_ami}"
    instance_type = "${var.aws_instance_type}"
    key_name      = "${var.ssh_keypair}"
    count         = "${var.num_nodes}"

    # Network interface #1 (eth0)
    vpc_security_group_ids = ["${var.our_security_group_id}"] 

    # only available for certain instance types
    #ebs_optimized = "true"

    root_block_device {
        delete_on_termination = "true"
    }

    tags {
        # this is the "Name" field in the Instances view.
        Name = "Jenkins-Netplugin-${var.buildnum}-${count.index}"
    }
}

# defined in aws.tfvars
variable "our_security_group_id" {}
variable "our_vpc_id" {}
variable "ssh_keypair" {}
variable "key_path" {}

variable "aws_ami" {
    default = "ami-af4333cf" # CentOS 7 AMI
}

variable "aws_instance_type" {
    default = "t2.large"
}

# how many VMs to spin up. 
# 
# default test setup needs 3 VMs.
variable "num_nodes" {
    default = "3"
}

# ============================================
# networks
#
# vars
# for convenience, we are using a pre-defined security group, its 
# associated vpc and subnet.
#
# for the second interface, define a new subnet inside the vpc.


# eth1 - vxlan network
resource "aws_network_interface" "netplugin_vxlan_interface" {
    subnet_id = "${aws_subnet.netplugin_vxlan_subnet.id}"
    security_groups = ["${var.our_security_group_id}"]
    count = "${var.num_nodes}"

    # tell which instance(s) this interface belongs to
    attachment {
        instance = "${element(aws_instance.jenkins_netplugin.*.id, count.index)}"
        device_index = 1
    }
}

resource "aws_subnet" "netplugin_vxlan_subnet" {
    vpc_id = "${var.our_vpc_id}"
    # creates a different subnet using buildnum to generate a number
    # between 100 and 200
    cidr_block = "172.31.${var.buildnum%100 + 100}.0/24"
    availability_zone = "us-west-1b"
}


# ============================================
# post-launch commands
#
# these will be run on each instance after it is launched

variable "ssh_user" {
  default = "centos"
}

# setup eth1 with IP# for all instances
resource "null_resource" "configure-interfaces" {
    count = "${var.num_nodes}"
    triggers {
        jenkins_netplugin_instance_ids = "${join(",", aws_instance.jenkins_netplugin.*.id)}"
    }

    provisioner "remote-exec" {
        inline = ["sudo /sbin/ip addr add '172.31.${var.buildnum%100}.1${count.index}/24' dev eth1 && sudo /sbin/ip link set dev eth1 up"]
    }

    connection {
        type = "ssh"
        user = "${var.ssh_user}"
        private_key = "${file(var.key_path)}"
        agent = false
        host = "${element(aws_instance.jenkins_netplugin.*.public_ip, count.index)}"
    }

}

# WIP - have not tried the ansible command yet.
# need to strip out the hardcoded IP#'s and use something like:
#    jenkins_netpugin_instance_ids.index = 0

#resource "null_resource" "ansible" {
#  triggers {
#    jenkins_netplugin_instance_ids = "${join(",", aws_instance.jenkins_netplugin.*.id)}"
#  }
#
#  connection {
#    user = "${var.ssh_user}"
#    host = "${element(aws_eip.netplugin-eip.*.public_ip, count.index)}"
#  }
#
# this is the command to run on the instance.
#  provisioner "local-exec" {
#    command = "echo \"[service-master]\\n${aws_eip.netplugin-eip.0.public_ip}\\n[service-worker]\\n${join("\n", aws_eip.netplugin-eip.*.public_ip)}\" >/tmp/hosts && ansible-playbook -e '{ \"netplugin_if\": \"eth2\", \"netmaster_ip\": \"10.1.10.10\", \"control_interface\": \"eth1\", \"env\": {} }' -i /tmp/hosts --ssh-extra-args='-o StrictHostKeyChecking=false' -T 300 -u ${var.ssh_user} site.yml"
#  }

#}

# ============================================
# Output section

output  "public_ip_addresses" {
    value = ["${aws_instance.jenkins_netplugin.public_ip}"]
}
