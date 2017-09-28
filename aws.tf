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

variable "aws_availability_zone" {
    default = "us-west-1b"
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
    default = "ami-7c280d1c" # CentOS 7 AMI
}

variable "aws_instance_type" {
    default = "t2.small"
}

# how many VMs to spin up. 
# 
# default test setup needs 3 VMs.
variable "num_nodes" {
    default = "3"
}

# ============================================
# Output section

output  "public_ip_addresses" {
    value = ["${aws_instance.jenkins_netplugin.*.public_ip}"]
}

output  "private_ip_addresses" {
    value = ["${aws_instance.jenkins_netplugin.*.private_ip}"]
}
