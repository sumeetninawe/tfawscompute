//VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = var.azs
  public_subnets  = var.subnet_cidr
}

//EC2 Instances
resource "aws_instance" "compute_nodes" {
  ami                       = var.ami
  instance_type             = var.instance_type
  count                     = length(var.azs)
  security_groups           = [aws_security_group.alb_sg.id]
  subnet_id                 = element(module.vpc.public_subnets, count.index)

  user_data = data.template_file.user_data.rendered
  
  tags = {
    Name = "my-compute-node-${count.index}"
  }
}

//User data
data "template_file" "user_data" {
    template = file("install.tpl")
}

//Loadbalancer Security group
resource "aws_security_group" "alb_sg" {
  name        = "my-alb-security-grp"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//ALB
resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

//Target Group
resource "aws_lb_target_group" "alb_tg" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "target_registration" {
  count = length(var.azs)
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.compute_nodes[count.index].id
  port             = 80
}

//ALB Listener
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}