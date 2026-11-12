resource "aws_security_group" "webapp_sg" {
    name        = "webapp-sg"
    description = "security group for webapp"
    vpc_id      = aws_vpc.webapp_vpc.id
    tags = {
        Name = "webapp-sg"
    }
}
resource "aws_security_group" "webapp_lb_sg" {
    name        = "webapp-lb-sg"
    description = "security group for webapp load balancer"
    vpc_id      = aws_vpc.webapp_vpc.id
    tags = {
        Name = "webapp-lb-sg"
    }
}

resource "aws_security_group_rule" "ssh" {
    type              = "ingress"
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    security_group_id = aws_security_group.webapp_sg.id
}

resource "aws_security_group_rule" "lb_http" {
    type              = "ingress"
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    security_group_id = aws_security_group.webapp_lb_sg.id
}

resource "aws_security_group_rule" "lb_to_webapp" {
    type                     = "ingress"
    from_port                = 80
    to_port                  = 80
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.webapp_lb_sg.id
    security_group_id        = aws_security_group.webapp_sg.id
}

resource "aws_vpc" "webapp_vpc" {
    cidr_block = "10.1.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "webapp_vpc"
    }
}

resource "aws_subnet" "webapp_subnet_private_1" {
    vpc_id   = aws_vpc.webapp_vpc.id
    cidr_block = "10.1.1.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name = "webapp-subnet-private-1" 
    }   
}    

resource "aws_subnet" "webapp_subnet_private_2" {
    vpc_id   = aws_vpc.webapp_vpc.id
    cidr_block = "10.1.2.0/24"
    availability_zone = "us-east-1b"
    tags = {
        Name = "webapp-subnet-private-2" 
    }   
}

resource "aws_subnet" "webapp_subnet_public_1" {
    vpc_id   = aws_vpc.webapp_vpc.id
    cidr_block = "10.1.3.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "webapp-subnet-public-1" 
    }   
} 

resource "aws_subnet" "webapp_subnet_public_2" {
    vpc_id   = aws_vpc.webapp_vpc.id
    cidr_block = "10.1.4.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    tags = {
        Name = "webapp-subnet-public-2" 
    }   
}

resource "aws_internet_gateway" "webapp_igw" {
    vpc_id = aws_vpc.webapp_vpc.id
    tags = {
        Name = "webapp-igw"
    }
}

resource "aws_route_table" "webapp_public_rt" {
    vpc_id = aws_vpc.webapp_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.webapp_igw.id
    }
    tags = {
        Name = "webapp-public-rt"
    }
}

resource "aws_route_table_association" "webapp_public_rt_assoc_1" {
    subnet_id      = aws_subnet.webapp_subnet_public_1.id
    route_table_id = aws_route_table.webapp_public_rt.id
}

resource "aws_route_table_association" "webapp_public_rt_assoc_2" {
    subnet_id      = aws_subnet.webapp_subnet_public_2.id
    route_table_id = aws_route_table.webapp_public_rt.id
}

resource "aws_route_table" "webapp_private_rt" {
    vpc_id = aws_vpc.webapp_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.webapp_nat_gw.id
    }
    tags = {
        Name = "webapp-private-rt"
    }
}
resource "aws_route_table_association" "webapp_private_rt_assoc_1" {
    subnet_id      = aws_subnet.webapp_subnet_private_1.id
    route_table_id = aws_route_table.webapp_private_rt.id
}

resource "aws_route_table_association" "webapp_private_rt_assoc_2" {
    subnet_id      = aws_subnet.webapp_subnet_private_2.id
    route_table_id = aws_route_table.webapp_private_rt.id
}


resource "aws_nat_gateway" "webapp_nat_gw" {
    allocation_id = aws_eip.webapp_nat_eip.id
    subnet_id     = aws_subnet.webapp_subnet_public_1.id
    depends_on    = [aws_internet_gateway.webapp_igw]
    tags = {
        Name = "webapp-nat-gw"
    }
}

resource "aws_eip" "webapp_nat_eip" {
    domain = "vpc"
    tags = {
        Name = "webapp-nat-eip"
    }
}