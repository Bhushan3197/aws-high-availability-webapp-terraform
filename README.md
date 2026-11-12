# My Project
# AWS Highly Available Web Application Infrastructure using Terraform

## Project Overview

This project provisions a highly available web application infrastructure on **Amazon Web Services (AWS)** using **Terraform (Infrastructure as Code)**.

The architecture uses an Application Load Balancer (ALB) to distribute incoming HTTP traffic across EC2 instances managed by an Auto Scaling Group (ASG). The EC2 instances run in private subnets across multiple Availability Zones, while the load balancer is deployed in public subnets.

A NAT Gateway provides outbound internet connectivity to resources in the private subnets without exposing the EC2 instances directly to the internet.

The infrastructure is provisioned and managed entirely through Terraform.

## Architecture

### High-Level Architecture

```text
                       Internet
                          |
                          |
                 Internet Gateway
                          |
                 +----------------+
                 |  Public Subnets|
                 |                |
                 | Application    |
                 | Load Balancer  |
                 +----------------+
                          |
                     HTTP : 80
                          |
             +------------+------------+
             |                         |
       Private Subnet 1          Private Subnet 2
       us-east-1a                us-east-1b
             |                         |
         EC2 Instance              EC2 Instance
             |                         |
             +------------+------------+
                          |
                   Auto Scaling Group
                    Desired: 2
                    Minimum: 2
                    Maximum: 4

             Private Route Table
                          |
                     NAT Gateway
                          |
                  Internet Gateway
                          |
                       Internet
```

### AWS Resources Provisioned

| AWS Resource | Description |
|---|---|
| VPC | Custom VPC with CIDR `10.1.0.0/16` |
| Public Subnets | Two public subnets across AZs |
| Private Subnets | Two private subnets across AZs |
| Internet Gateway | Internet connectivity for public subnets |
| NAT Gateway | Outbound internet access for private subnets |
| Elastic IP | Static public IP assigned to NAT Gateway |
| Route Tables | Separate public and private routing |
| Security Groups | Separate security groups for ALB and EC2 |
| Application Load Balancer | Distributes incoming HTTP traffic |
| Target Group | Registers and monitors EC2 instances |
| Launch Template | Defines EC2 instance configuration |
| Auto Scaling Group | Maintains and scales EC2 instances |
| EC2 Instances | Hosts the Apache web application |
| Key Pair | Provides SSH authentication |

## Network Architecture

### VPC Configuration

- VPC CIDR: `10.1.0.0/16`
- Region: `us-east-1` (N. Virginia)
- DNS support enabled.
- DNS hostnames enabled.

### Subnet Configuration

| Subnet | Availability Zone | CIDR | Type |
|---|---|---|---|
| Public Subnet 1 | us-east-1a | 10.1.3.0/24 | Public |
| Public Subnet 2 | us-east-1b | 10.1.4.0/24 | Public |
| Private Subnet 1 | us-east-1a | 10.1.1.0/24 | Private |
| Private Subnet 2 | us-east-1b | 10.1.2.0/24 | Private |

### Routing Configuration

**Public Route Table**
- Associated with both public subnets.
- Default route `0.0.0.0/0` points to the Internet Gateway.

**Private Route Table**
- Associated with both private subnets.
- Default route `0.0.0.0/0` points to the NAT Gateway.

This allows:
- Public ALB to receive internet traffic.
- Private EC2 instances to access the internet for outbound operations.
- EC2 instances to remain inaccessible through direct public internet connections.

## Application Load Balancer

An internet-facing Application Load Balancer is deployed across both public subnets.

Configuration:
- Load balancer type: Application Load Balancer.
- Listener protocol: HTTP.
- Listener port: 80.
- Default action: Forward traffic to the web application target group.

### Target Group

- Protocol: HTTP.
- Port: 80.
- Health check path: `/`.
- Health check interval: 30 seconds.
- Healthy threshold: 2.
- Unhealthy threshold: 2.

The target group is associated with the Auto Scaling Group to automatically register and deregister EC2 instances.

## Auto Scaling Group

The Auto Scaling Group manages EC2 instances across both private subnets.

| Configuration | Value |
|---|---|
| Desired capacity | 2 |
| Minimum capacity | 2 |
| Maximum capacity | 4 |
| Health check type | ELB |
| Launch configuration | Launch Template |
| Target group | webapp-tg |

The Auto Scaling Group maintains the desired instance capacity and integrates with the Application Load Balancer for health monitoring.

## EC2 Launch Template

The Launch Template defines the configuration for EC2 instances.

- AMI: Configurable through Terraform variables.
- Instance type: `t3.micro` (configurable).
- Security group: `webapp-sg`.
- SSH key pair: `webapp-key`.
- User data: Installs and starts Apache HTTP Server.

### User Data Script

```bash
#!/bin/bash

yum install -y httpd

systemctl enable --now httpd

systemctl start httpd

echo "Hello from $(hostname -f)" > /var/www/html/index.html
```

Each EC2 instance serves a webpage displaying its hostname.

This helps verify that the ALB distributes requests across different instances.

## Security Groups

Two separate security groups are configured.

### 1. webapp-lb-sg

Attached to the Application Load Balancer.

| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | TCP | 80 | 0.0.0.0/0 |

### 2. webapp-sg

Attached to EC2 instances.

| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | TCP | 22 | 0.0.0.0/0 |
| Inbound | TCP | 80 | webapp-lb-sg |

The application security group allows HTTP traffic only from the load balancer security group.

**Note:** Explicit outbound rules are not defined in the current Terraform configuration. Verify the effective AWS rules and configure the required egress permissions explicitly.

## Terraform Project Structure

```text
aws-webapp-terraform/
│
├── firewall.tf
│   └── VPC, subnets, route tables,
│       NAT Gateway, Elastic IP,
│       and Security Groups
│
├── main.tf
│   └── Launch Template, Auto Scaling Group,
│       Application Load Balancer,
│       Target Group and Listener
│
├── pem.tf
│   └── AWS EC2 Key Pair
│
├── provider.tf
│   └── Terraform and AWS provider configuration
│
├── variable.tf
│   └── Input variable declarations
│
├── terraform.tfvars
│   └── Variable values (AMI ID and instance type)
│
└── README.md
    └── Project documentation
```

## Prerequisites

Before deploying the infrastructure, ensure you have:

1. An AWS account.
2. AWS CLI installed and configured.
3. Terraform installed.
4. Git installed.
5. An appropriate Amazon Linux AMI ID for the `us-east-1` region.
6. An SSH key pair available locally.

### Configure AWS CLI

```bash
aws configure
```

Provide your AWS access key, secret key, default region (`us-east-1`), and output format.

### Generate SSH Key Pair

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/webapp-key
```

The Terraform configuration references:

```text
~/.ssh/webapp-key.pub
```

Keep the private key secure.

## Deployment Instructions

### Step 1: Clone the Repository

```bash
git clone <your-github-repository-url>
cd aws-webapp-terraform
```

### Step 2: Initialize Terraform

```bash
terraform init
```

This downloads the required AWS provider and initializes the working directory.

### Step 3: Validate Configuration

```bash
terraform validate
```

Checks the Terraform configuration for syntax and configuration errors.

### Step 4: Review Execution Plan

```bash
terraform plan
```

Reviews the infrastructure changes Terraform intends to make.

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Review the execution plan and confirm by entering `yes`.

Terraform provisions the VPC, networking components, security groups, NAT Gateway, load balancer, launch template, and Auto Scaling Group.

### Step 6: Verify Deployment

Navigate to:

**AWS Console → EC2 → Load Balancers**

Copy the DNS name of the `webapp-lb` Application

Open it in your browser:

http://<your-load-balancer-dns-name>

Alternatively, test using curl:

curl -v http://<your-load-balancer-dns-name>

Expected response:

Hello from ip-10-1-x-x.ec2.internal

Refresh the page or send multiple requests to observe responses from different EC2 instances.

Step 7: Verify Auto Scaling

Navigate to:

AWS Console → EC2 → Auto Scaling Groups

Check the webapp_asg group.

Verify:

Desired capacity: 2.

Minimum capacity: 2.

Maximum capacity: 4.

EC2 instances registered with the target group.

Target health status is Healthy.

Terraform Variables

The project uses input variables to make the infrastructure configurable.

variable.tf

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to use for the EC2 instance"
  type        = string
}

terraform.tfvars

ami_id        = "your-ami-id"
instance_type = "t3.micro"

Update the AMI ID according to the AWS region and operating system you intend to use.

Cleanup

To avoid unnecessary AWS charges, destroy the infrastructure when it is no longer required.

terraform destroy

Review the resources that will be removed and confirm with yes.

Important: NAT Gateways, Elastic IPs, and load balancers can incur AWS charges while provisioned. Destroy unused infrastructure.

Security Considerations

This project is intended as a learning and demonstration environment. Before using it in production, consider the following improvements:

Restrict SSH access to trusted IP addresses or use AWS Systems Manager Session Manager.

Define explicit outbound security group rules based on application requirements.

Implement HTTPS using AWS Certificate Manager (ACM).

Enable ALB access logs.

Store Terraform state remotely using an S3 backend with state locking.

Avoid committing AWS credentials, private SSH keys, or Terraform state files to GitHub.

Consider deploying NAT Gateways in multiple Availability Zones for improved availability.

Use least-privilege IAM policies.

Key Learnings

Through this project, I explored and implemented:

AWS VPC and subnet architecture.

Public and private subnet networking.

Internet Gateway and NAT Gateway routing.

AWS Security Groups and stateful traffic filtering.

Application Load Balancer and target groups.

EC2 Launch Templates.

Auto Scaling Groups and health checks.

EC2 user data and Apache installation.

Terraform infrastructure provisioning and resource dependencies.

Troubleshooting connectivity between ALB and private EC2 instances.

Future Enhancements

Potential improvements to extend this project:

Configure HTTPS using AWS ACM.

Implement Terraform remote state using S3.

Implement a multi-AZ NAT Gateway architecture.

Add CloudWatch monitoring and alarms.

Integrate a CI/CD pipeline using GitHub Actions.

Implement AWS Systems Manager for instance management.

Add AWS WAF for application protection.

Implement Terraform modules for reusable infrastructure.

Author

Bhushan Munghate

Cloud Operations Engineer | AWS | Terraform | DevOps | Infrastructure Automation

[LinkedIn](https://www.linkedin.com/in/bhushan-munghate-496176141/)

This project is part of my hands-on learning journey in AWS Cloud Infrastructure, Terraform, and DevOps engineering.