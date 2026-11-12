
resource "aws_autoscaling_group" "webapp_asg" {
##description = "Auto Scaling Group for WebApp"
    vpc_zone_identifier = [
        aws_subnet.webapp_subnet_private_1.id, 
        aws_subnet.webapp_subnet_private_2.id,
        ]
    launch_template {
        id = aws_launch_template.webapp_lt.id
        version = "$Latest"
    }
    target_group_arns = [aws_lb_target_group.webapp_tg.arn]
    desired_capacity = 2
    min_size =  2
    max_size = 4
    health_check_type = "ELB"
    tag{
            key                 = "Name"
            value               = "WebAppASG"
            propagate_at_launch = true
}
}

resource "aws_launch_template" "webapp_lt" {
    name          = "webapp-lt"
    image_id      = var.ami_id
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.webapp_sg.id]
    key_name = aws_key_pair.webapp_key.key_name
    lifecycle {
        create_before_destroy = true
    }   
    user_data = base64encode(<<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl enable --now httpd
    systemctl start httpd
    echo "Hello from $(hostname -f)" > /var/www/html/index.html
  EOF
  )
}

resource "aws_lb" "webapp_lb" {
    name               = "webapp-lb"
    load_balancer_type = "application"    
    security_groups    = [aws_security_group.webapp_lb_sg.id]
    subnets            = [aws_subnet.webapp_subnet_public_1.id, aws_subnet.webapp_subnet_public_2.id]
}

resource "aws_lb_target_group" "webapp_tg" {
    name     = "webapp-tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.webapp_vpc.id
    health_check {
        path                = "/"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
    tags = {
        Name = "webapp-tg"
    }
}

resource "aws_lb_listener" "webapp_listener" {
    load_balancer_arn = aws_lb.webapp_lb.arn
    port              = 80
    protocol          = "HTTP"
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.webapp_tg.arn
    }
}