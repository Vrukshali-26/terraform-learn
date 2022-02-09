# Creating a VPC
resource "aws_vpc" "main-vpc" {
    cidr_block = var.cidr_block[0]
    tags = {
        Name = "${var.name}-vpc"
    }  
}

# Creating a subnet
resource "aws_subnet" "main-subnet" {
    vpc_id = aws_vpc.main-vpc.id 
    cidr_block = var.cidr_block[1]
    tags = {
      "Name" = "${var.name}-subnet"
    }
    availability_zone = var.az
}

# Creating Internet Gateway
resource "aws_internet_gateway" "main-ig" {
    vpc_id = aws_vpc.main-vpc.id
    tags = {
        Name = "${var.name}-ig"
    }
}

# Creating route table
resource "aws_route_table" "main-rtb" {
    vpc_id = aws_vpc.main-vpc.id
    route {
        cidr_block = var.cidr_block[2]
        gateway_id = aws_internet_gateway.main-ig.id
    }
    tags = {
        Name = "${var.name}-rtb"
    }
}

# Route table association
resource "aws_route_table_association" "main-rtb-ass" {
    subnet_id = aws_subnet.main-subnet.id
    route_table_id = aws_route_table.main-rtb.id
}

# Creating security groups
resource "aws_security_group" "main-sg" {
    name = "${var.name}-sg"
    vpc_id = aws_vpc.main-vpc.id

    ingress {
      cidr_blocks = [ var.cidr_block[3] ]
      from_port = 22
      protocol = "tcp"
      to_port = 22
    }

    ingress {
      cidr_blocks = [ var.cidr_block[2] ]
      from_port = 8080
      protocol = "tcp"
      to_port = 8080
    }

    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = [ var.cidr_block[2] ]
  }

    tags = {
        Name = "${var.name}-sg"
    }
}

# AMI for instance
data "aws_ami" "ami-for-instance" {
    most_recent = true

    filter {
      name = "name"
      values = ["amzn2-ami-kernel-*-gp2"]
    }

    filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

    owners = ["137112412989"]
}

# Creating instance
resource "aws_instance" "main-instance" {
    ami = data.aws_ami.ami-for-instance.id
    instance_type = var.instance

    associate_public_ip_address = true
    availability_zone = var.az
    security_groups = [aws_security_group.main-sg.id]
    subnet_id = aws_subnet.main-subnet.id
    vpc_security_group_ids = [ aws_security_group.main-sg.id  ]

    key_name = var.key

    connection {
            type     = "ssh"
            user     = "ec2-user"
            private_key = file("${var.file}/key.pem")
            host     = aws_instance.main-instance.public_ip
    }

    provisioner "remote-exec" {
    inline = [
      "sudo yum update",
      "sudo yum install docker -y",
      "sudo systemctl start docker",
      "sudo groupadd docker",
      "sudo usermod -aG docker ec2-user",
      "sudo docker run -d -p 8080:80 nginx:latest"

    ]
  }

    tags = {
        Name = "${var.name}-instance"
    }
}

output "instance_ip" {
  value = aws_instance.main-instance.public_ip
}