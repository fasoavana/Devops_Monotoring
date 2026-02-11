# 1. VPC
resource "aws_vpc" "blog_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "blog-vpc"
  }
}

# 2. Sous-réseau public
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.blog_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "blog-public-subnet"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.blog_vpc.id
  
  tags = {
    Name = "blog-igw"
  }
}

# 4. Route Table publique
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.blog_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "blog-public-rt"
  }
}

# 5. Association sous-réseau -> route table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Groupe de sécurité
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Autorise HTTP, SSH"
  vpc_id      = aws_vpc.blog_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API"
    from_port   = 5000
    to_port     = 5000
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
    Name = "blog-web-sg"
  }
}

# 7. Instance EC2
resource "aws_instance" "web_server" {
  ami                         = "ami-0c55b159cbfafe1f0"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "blog-web-server"
  }
}

# 8. Bucket S3
###resource "aws_s3_bucket" "media_bucket" {
###  bucket = "blog-media-bucket-local"
###  
###  tags = {
###    Name = "blog-media"
###  }
###}
##
### 9. Outputs
##output "instance_public_ip" {
##  value = aws_instance.web_server.public_ip
##}
#
#output "s3_bucket_name" {
#  value = aws_s3_bucket.media_bucket.bucket
#}

output "vpc_id" {
  value = aws_vpc.blog_vpc.id
}

output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}
