#Configure Provider
provider "aws" {
  profile = "default"
  region  = "ap-south-1"
  access_key = "AKIAILGLGI6FVXPXGBNA"
  secret_key = "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"
}

#Creating VPC
resource "aws_vpc" "myvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "personal_vpc"
  }
}

#Public Subnet
resource "aws_subnet" "s1" {
  vpc_id     = "${aws_vpc.myvpc.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "subnet-1a"
  }
}

#Private Subnet
resource "aws_subnet" "s2" {
  vpc_id     = "${aws_vpc.myvpc.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone  = "ap-south-1b"
  
  tags = {
    Name = "subnet-1b"
  }
}

#Elastc IP
resource "aws_eip" "elasticip"{
  vpc=true
  
  tags = {
    Name = "Eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.elasticip.id
  subnet_id = aws_subnet.s1.id
  
  tags = {
    Name = "NATGATEWAY"
  }
}


#Internet gateway
resource "aws_internet_gateway" "gateway1" {
  vpc_id = "${aws_vpc.myvpc.id}"

  tags = {
    Name = "personal_vpc_gateway"
  }
}

#Routing table for internet gateway
resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.myvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway1.id}"
  }

  tags = {
    Name = "new_route_table"
  }
}
resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.s1.id
  route_table_id = aws_route_table.rt.id
}

#Routing table for private subnet
resource "aws_route_table" "rout_nat" {
  vpc_id = "${aws_vpc.myvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }

  tags = {
    Name = "NAT_route_table"
  }
}
resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.s2.id
  route_table_id = aws_route_table.rt.id
}


#Key
resource "tls_private_key" "webserver_key" {
    algorithm   =  "RSA"
    rsa_bits    =  4096
}
resource "local_file" "private_key" {
    content         =  tls_private_key.webserver_key.private_key_pem
    filename        =  "my-key.pem"
    file_permission =  0400
}
resource "aws_key_pair" "webserver_key" {
    key_name   = "my-key"
    public_key = tls_private_key.webserver_key.public_key_openssh
}

#Security Groups
resource "aws_security_group" "sg1" {
  name        = "wordpress_security_group"
  vpc_id      = aws_vpc.myvpc.id

   ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name       = "wordpress_security_group"
  }
}
resource "aws_security_group" "sg2" {
  name        = "sql_security_group"
  vpc_id      = aws_vpc.myvpc.id

   ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.sg1.id]
  }

  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name       = "sql_security_group"
  }
}
resource "aws_instance" "OS1"{
  ami             = "ami-000cbce3e1b899ebd"
  instance_type   = "t2.micro"
  associate_public_ip_address = true
  key_name        = "my-key"
  security_groups = [aws_security_group.sg1.id]
  subnet_id       = aws_subnet.s1.id
  
  tags = {
     Name = "Wordpress_Instance"
  }
}
resource "aws_instance" "OS2"{
  ami             = "ami-0019ac6129392a0f2"
  instance_type   = "t2.micro"
  key_name        = "my-key"
  security_groups = [aws_security_group.sg2.id]
  subnet_id       = aws_subnet.s2.id
  
  tags = {
     Name = "MYSQL_Instance"
  }
}
