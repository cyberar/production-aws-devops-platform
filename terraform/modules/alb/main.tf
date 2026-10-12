resource "aws_lb" "main" {
  name               = "production-devops-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [var.alb_security_group_id]
  subnets         = var.public_subnet_ids

  tags = {
    Name = "production-devops-alb"
  }
}


resource "aws_lb_target_group" "blue" {
  name     = "production-blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "production-blue-tg"
    Environment = "blue"
  }
}


resource "aws_lb_target_group" "green" {
  name     = "production-green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "production-green-tg"
    Environment = "green"
  }
}


resource "aws_lb_target_group_attachment" "blue" {
  target_group_arn = aws_lb_target_group.blue.arn
  target_id        = var.blue_instance_id
  port             = 80
}


resource "aws_lb_target_group_attachment" "green" {
  target_group_arn = aws_lb_target_group.green.arn
  target_id        = var.green_instance_id
  port             = 80
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

resource "aws_lb_listener_rule" "green_test" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  condition {
    path_pattern {
      values = ["/green", "/green/*"]
    }
  }
}