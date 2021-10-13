terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

# Configure the AWS Provider
provider "aws" {
    #access_key = "${var.access_key}"
    #secret_key = "${var.secret_key}"
    profile = "${var.profile}"
    region = "${var.region}"
}

# Create VPC
resource "aws_vpc" "pavm-vpc" {
    cidr_block = "${var.vpc_cidr_block}"
    enable_dns_support = true 
    enable_dns_hostnames = false
    tags = {
        Name = "pavm-vpc"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "pavm-igw" {
  vpc_id = aws_vpc.pavm-vpc.id
  tags = {
    Name = "pavm-igw"
  }
}

# Create Public subnet
resource "aws_subnet" "public-subnet" {
    count = length(var.public_subnet_cidr_block)
    vpc_id = "${aws_vpc.pavm-vpc.id}"
    cidr_block = element(var.public_subnet_cidr_block,count.index)
    availability_zone = element(var.availability_zone,count.index)
    map_public_ip_on_launch = true
    tags = {
        Name = "public-subnet-${count.index+1}"
    }
}

# Route table: attach Internet Gateway 
resource "aws_route_table" "public_rt" {
  vpc_id = "${aws_vpc.pavm-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.pavm-igw.id}"
  }
  tags = {
    Name = "public_rt"
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "a" {
  count = length(var.availability_zone)
  subnet_id = element(aws_subnet.public-subnet.*.id,count.index)
  route_table_id = aws_route_table.public_rt.id
}

# Create Prviate subnet
resource "aws_subnet" "private-subnet" {
    count = length(var.private_subnet_cidr_block)
    vpc_id = "${aws_vpc.pavm-vpc.id}"
    cidr_block = element(var.private_subnet_cidr_block,count.index)
    availability_zone = element(var.availability_zone,count.index)
    map_public_ip_on_launch = false
    tags = {
        Name = "private-subnet-${count.index+1}"
    }
}

# Security Group allow ingress
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id = "${aws_vpc.pavm-vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-APP"
  }
}


resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = "${lookup(var.pavm_ami_id, var.region)}" 
  instance_type = "t2.micro"
  key_name = "${var.key_name}"

  security_groups = [ aws_security_group.allow_http.id ]
  associate_public_ip_address = true

  user_data = <<EOF
#  start nginx
/usr/share/nginx/html/index.html
chkconfig nginx on
service nginx start
EOF

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"
  vpc_id = "${aws_vpc.pavm-vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP through ELB Security Group"
  }
}

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.elb_http.id
  ]
  subnets = ["${aws_subnet.public-subnet.0.id}"]

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [
  	element(aws_subnet.public-subnet.*.id,0),
  	element(aws_subnet.public-subnet.*.id,1),
  	element(aws_subnet.public-subnet.*.id,2)
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}
