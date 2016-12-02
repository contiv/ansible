provider "aws" {
  region = "${var.aws_region}"
}

variable "nodes" {
  default = 3
}

variable "ami" {
  default = "ami-af4333cf"
}

variable "ssh_user" {
  default = "centos"
}

variable "aws_key_name" {
  description = "The name of your SSH key on AWS"
  type        = "string"
}

variable "rerun" {
  type    = "string"
  default = ""
}

variable "aws_region" {
  default = "us-west-1"
}

variable "instance_class" {
  default = "c3.large"
}

resource "aws_vpc" "netplugin-testvpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "netplugin-gw" {
  vpc_id = "${aws_vpc.netplugin-testvpc.id}"
}

resource "aws_route_table" "netplugin-rt" {
  vpc_id = "${aws_vpc.netplugin-testvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.netplugin-gw.id}"
  }
}

resource "aws_route_table_association" "netplugin-rta" {
  subnet_id      = "${aws_subnet.netplugin-main-subnet.id}"
  route_table_id = "${aws_route_table.netplugin-rt.id}"
}

resource "aws_subnet" "netplugin-main-subnet" {
  vpc_id     = "${aws_vpc.netplugin-testvpc.id}"
  cidr_block = "10.1.0.0/24"
}

resource "aws_subnet" "netplugin-control-subnet" {
  vpc_id            = "${aws_vpc.netplugin-testvpc.id}"
  cidr_block        = "10.1.10.0/24"
  availability_zone = "${aws_subnet.netplugin-main-subnet.availability_zone}"
}

resource "aws_subnet" "netplugin-vlan-subnet" {
  vpc_id            = "${aws_vpc.netplugin-testvpc.id}"
  cidr_block        = "10.1.20.0/24"
  availability_zone = "${aws_subnet.netplugin-main-subnet.availability_zone}"
}

resource "aws_security_group" "netplugin-sg" {
  vpc_id = "${aws_vpc.netplugin-testvpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "icmp"
    from_port   = 8
    to_port     = 8
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0
    self      = true
  }
}

resource "aws_eip" "netplugin-eip" {
  vpc      = true
  instance = "${element(aws_instance.netplugin-node.*.id, count.index)}"
  count    = "${var.nodes}"
}

resource "aws_network_interface" "netplugin-control-if" {
  subnet_id       = "${aws_subnet.netplugin-control-subnet.id}"
  security_groups = ["${aws_security_group.netplugin-sg.id}"]
  private_ips     = ["10.1.10.1${count.index}"]
  count           = "${var.nodes}"

  attachment {
    instance     = "${element(aws_instance.netplugin-node.*.id, count.index)}"
    device_index = 1
  }

  depends_on = ["aws_instance.netplugin-node", "aws_eip.netplugin-eip"]
}

resource "aws_network_interface" "netplugin-vlan-if" {
  subnet_id       = "${aws_subnet.netplugin-vlan-subnet.id}"
  security_groups = ["${aws_security_group.netplugin-sg.id}"]
  private_ips     = ["10.1.20.1${count.index}"]
  count           = "${var.nodes}"

  attachment {
    instance     = "${element(aws_instance.netplugin-node.*.id, count.index)}"
    device_index = 2
  }

  depends_on = ["aws_network_interface.netplugin-control-if"]
}

resource "aws_instance" "netplugin-node" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_class}"
  key_name               = "${var.aws_key_name}"
  subnet_id              = "${aws_subnet.netplugin-main-subnet.id}"
  count                  = "${var.nodes}"
  availability_zone      = "${aws_subnet.netplugin-main-subnet.availability_zone}"
  vpc_security_group_ids = ["${aws_security_group.netplugin-sg.id}"]
}

resource "null_resource" "configure-interfaces" {
  count = "${var.nodes}"

  provisioner "remote-exec" {
    inline = ["sudo /sbin/ip addr add '10.1.10.1${count.index}/24' dev eth1 && sudo /sbin/ip link set dev eth1 up"]
  }

  connection {
    user = "${var.ssh_user}"
    host = "${element(aws_eip.netplugin-eip.*.public_ip, count.index)}"
  }

  depends_on = ["aws_network_interface.netplugin-control-if"]
}

resource "null_resource" "ansible" {
  provisioner "local-exec" {
    command = "echo '
            [service-master]
            ${aws_eip.netplugin-eip.0.public_ip}
            [service-worker]
            ${join("\n", aws_eip.netplugin-eip.*.public_ip)}
            ' >/tmp/hosts && \\
            ansible-playbook -e '{ \"netplugin_if\": \"eth2\", \"netmaster_ip\": \"10.1.10.10\", \"control_interface\": \"eth1\", \"env\": {} }' -i /tmp/hosts --ssh-extra-args='-o StrictHostKeyChecking=false' -T 300 -u ${var.ssh_user} site.yml"
  }

  triggers {
    rerun                = "${rerun}"
    cluster_instance_ids = "${join(",", aws_instance.netplugin-node.*.id)}"
  }

  depends_on = ["null_resource.configure-interfaces"]
}
