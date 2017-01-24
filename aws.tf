terraform {
    required_version = "> 0.8.0"
}

# TODO: export env var TF_VAR_buildnum so we can use it inside here with the
# "name" tag for instances.
#
# eg. TF_VAR_buildnum=103, creates instances named:
# jenkins-netplugin-103-0
# jenkins-netplugin-103-1
# jenkins-netplugin-103-2
#
# easy to spot and clean-up if something goes wrong

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

# TODO: make keys for Jenkins
# NOTE: keys can only be alphanumeric. no special characters (- _ +)
# while these are valid for AWS, Terraform barfs on them  (bug.)
variable "aws_access_key" {
  default = "AKIAIOC2E3FDZ42O3JYA"
}

variable "aws_secret_key" {
  default = "Lgaq5j6Z8X8SdkrZhc57s1PDljsn714cxJW0Fb2m"
}

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
  vpc_security_group_ids = ["sg-83b3abe6"] 

# only available for certain instance types
#  ebs_optimized = "true"
  root_block_device {
    delete_on_termination = "true"
  }
  tags {
# this is the "Name" field in the Instances view.
# TODO: make this dynamic so we don't end up with 
# a bunch of machines with the same name.
      Name = "Jenkins-Netplugin-${var.buildnum}-${count.index}"
  }
}

variable "aws_ami" {
  default = "ami-af4333cf" # CentOS AMI
}

variable "aws_instance_type" {
  default = "t2.large"
}

variable "ssh_keypair" {
  default = "doug-cisco" # TODO: Make keypair for Jenkins
}

variable "num_nodes" {
  default = "3"
}

# ============================================
# networks
#
# vars
# for convenience, use the containerx security group and
# its associated vpc and subnet.
#
# for the second interface, define a new subnet inside
# the vpc.

# pre-defined security group & vpc
variable "cx_security_group" {
  default = "sg-83b3abe6"
}
variable "cx_vpc_id" {
  default = "vpc-2bf7264e"
}

# eth1 - private network
resource "aws_network_interface" "netplugin_vxlan_interface" {
  subnet_id = "${aws_subnet.netplugin_vxlan_subnet.id}"
  security_groups = ["${var.cx_security_group}"]
  count = "${var.num_nodes}"
  attachment {
    instance = "${element(aws_instance.jenkins_netplugin.*.id, count.index)}"
    device_index = 1
  }
}

resource "aws_subnet" "netplugin_vxlan_subnet" {
  vpc_id = "${var.cx_vpc_id}"
  # creates a different subnet each build between 100..200
  cidr_block = "172.31.${var.buildnum%100 + 100}.0/24"
  availability_zone = "us-west-1b"
}


# ============================================
# post-launch commands
#
# these will be run on each instance after it is launched

# copied from Erik's script, I haven't fully debugged this part yet, but
# it is a (mostly) working example of running anisble.
#
# need to strip out the hardcoded IP#'s and use something like:
#  jenkins_netpugin_instance_ids.index = 0

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
    private_key = "${file("/var/lib/jenkins/doug-cisco.pem")}"
    agent = false
    host = "${element(aws_instance.jenkins_netplugin.*.public_ip, count.index)}"
  }

}

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
    #value = ["${aws_instance.jenkins_netplugin.*}"]
    value = ["${aws_instance.jenkins_netplugin.publi_ip}"]
    #value = ["${aws_instance.jenkins_netplugin.*.public_ip}"]
}

