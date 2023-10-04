
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# Generates a secure private key and encodes it as PEM
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create the Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "${data.aws_region.current_region.name}-terraform-key"
  public_key = tls_private_key.key_pair.public_key_openssh
}
# Save file
resource "local_file" "ssh_key" {
  filename        = "${aws_key_pair.key_pair.key_name}.pem"
  content         = tls_private_key.key_pair.private_key_pem
  file_permission = "0400"

  provisioner "local-exec" {
    command = "ssh-add -k ${path.module}/${aws_key_pair.key_pair.key_name}.pem"
  }
}


# EC2 Instance
resource "aws_instance" "myec2" {
  count                       = var.ec2_count
  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.key_pair.key_name  #var.key
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.grad_proj_sg["public"].id]
  root_block_device {
    volume_size = 10
  }
  tags = {
    "Name" = "minikube_ec2"
  }

  provisioner "local-exec" {
    working_dir = "./minikube"
    command     = "export ec2_public_ip=${self.public_ip} ; envsubst < deploy-minikube-vars.yaml > deploy-minikube.yaml ; sleep 125 ; ansible-playbook --inventory ${self.public_ip}, --user ubuntu  deploy-minikube.yaml"
  }

  provisioner "local-exec" {
    working_dir = "./minikube"
    command     = "mv /home/ahmed/.kube/config /home/ahmed/.kube/config_before_ec2_minikube_man ; scp ubuntu@${self.public_ip}:/home/ubuntu/.kube/config.host /home/ahmed/.kube/config"
  }

}


resource "aws_ebs_volume" "additional_ebs_volumes" {
  count             = var.no_of_extra_ebs_volmes
  availability_zone = random_shuffle.az_list.result[0]
  size              = 5
  tags = {
    Name = "ebs_vol_${count.index + 1}"
  }
}

resource "aws_volume_attachment" "additional_ebs_volumes_attach" {
  count       = var.no_of_extra_ebs_volmes
  device_name = local.ebs_vol_names_array[count.index]
  volume_id   = aws_ebs_volume.additional_ebs_volumes[count.index].id
  instance_id = aws_instance.myec2[0].id
}



resource "aws_ebs_volume" "ebs_vol_1" {
  count             = var.extra_ebs_1 ? 1 : 0
  availability_zone = random_shuffle.az_list.result[0]
  size              = 5
  tags = {
    Name = "ebs_vol_1"
  }
}
resource "aws_volume_attachment" "ebs_att_1" {
  count       = var.extra_ebs_1 ? 1 : 0
  device_name = "/dev/sdx"
  volume_id   = aws_ebs_volume.ebs_vol_1[0].id
  instance_id = aws_instance.myec2[0].id
}

resource "aws_ebs_volume" "ebs_vol_2" {
  count             = var.extra_ebs_2 ? 1 : 0
  availability_zone = random_shuffle.az_list.result[0]
  size              = 5
  tags = {
    Name = "ebs_vol_2"
  }
}
resource "aws_volume_attachment" "ebs_att_2" {
  count       = var.extra_ebs_2 ? 1 : 0
  device_name = "/dev/sdy"
  volume_id   = aws_ebs_volume.ebs_vol_2[0].id
  instance_id = aws_instance.myec2[0].id
}

resource "aws_ebs_volume" "ebs_vol_3" {
  count             = var.extra_ebs_2 ? 1 : 0
  availability_zone = random_shuffle.az_list.result[0]
  size              = 5
  tags = {
    Name = "ebs_vol_3"
  }
}
resource "aws_volume_attachment" "ebs_att_3" {
  count       = var.extra_ebs_3 ? 1 : 0
  device_name = "/dev/sdz"
  volume_id   = aws_ebs_volume.ebs_vol_3[0].id
  instance_id = aws_instance.myec2[0].id
}

resource "aws_network_interface" "additional_nic" {
  count           = var.extra_nic ? 1 : 0
  subnet_id       = aws_subnet.public[0].id
  security_groups = ["${aws_security_group.grad_proj_sg["public"].id}"]
}

resource "aws_network_interface_attachment" "additional_nic_assoc" {
  count                = var.extra_nic ? 1 : 0
  instance_id          = aws_instance.myec2[0].id
  network_interface_id = aws_network_interface.additional_nic[count.index].id
  device_index         = 1
}

resource "aws_eip" "extra_public_ip" {
  count = var.extra_nic ? 1 : 0
}

resource "aws_eip_association" "eip_assoc" {
  count                = var.extra_nic ? 1 : 0
  network_interface_id = aws_network_interface.additional_nic[count.index].id
  allocation_id        = aws_eip.extra_public_ip[count.index].id
}

output "the_pubic_ip_of_the_ec2_instance" {
  value = (var.ec2_count > 0) ? aws_instance.myec2[0].public_ip : ""
}



