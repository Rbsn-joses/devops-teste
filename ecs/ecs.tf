terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}
provider "aws" {
  region  = var.region
  shared_config_files      = ["${HOME}/.aws/config"]
  shared_credentials_files = ["${HOME}/.aws/credentials"]
}
# main.tf
resource "aws_ecs_cluster" "devops-teste" {
  name = "devops-test" # Name your cluster here
}




data "aws_vpc" "default" {
 default = true
}
data "aws_subnet_ids" "test_subnet_ids" {
  vpc_id = data.aws_vpc.default.id
}
data "aws_subnet" "test_subnet" {
  count = "${length(data.aws_subnet_ids.test_subnet_ids.ids)}"
  id    = "${tolist(data.aws_subnet_ids.test_subnet_ids.ids)[count.index]}"
}
resource "aws_security_group" "http_access_ecs" {
  name        = "http_access_ecs"
  description = "teste devops ecs"
  vpc_id = data.aws_vpc.default.id


  ingress {
    from_port   = 3000
    to_port     = 3000
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
resource "aws_alb" "application_load_balancer" {
  name               = "load-balancer-teste"
  subnets = "${data.aws_subnet.test_subnet.*.id}"
  load_balancer_type = "application"
  # security group
  security_groups = [aws_security_group.http_access_ecs.id]
}
resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.id #  load balancer
  port              = 3000
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.id # target group
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name                = "ecsTaskExecutionRole"
  assume_role_policy  = data.aws_iam_policy_document.execution_assume_role_policy.json
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

data "aws_iam_policy_document" "execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ecsTaskExecutionRole_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecsTaskExecutionRole_policy.arn
}
# main.tf
resource "aws_ecs_task_definition" "app-first-service" {
  family                   = "app-first-task" # Name your task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "app-first-service",
      "image": "rbsnjoses/devops-teste:10001756312",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # use Fargate as the launch type
  network_mode             = "awsvpc"    # add the AWS VPN network mode as this is required for Fargate
  memory                   = 512         # Specify the memory the container requires
  cpu                      = 256         # Specify the CPU the container requires
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}
resource "aws_ecs_service" "app_service" {
  lifecycle { create_before_destroy = true }
  name            = "app-first-service"     # Name the service
  cluster         = aws_ecs_cluster.devops-teste.name  # Reference the created Cluster
  task_definition = aws_ecs_task_definition.app-first-service.arn # Reference the task that the service will spin up
  launch_type     = "FARGATE"
  desired_count   = 1 # Set up the number of containers to 3

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn # Reference the target group
    container_name   = "app-first-service"
    container_port   = 3000 # Specify the container port
  }

  network_configuration {
    subnets = "${data.aws_subnet.test_subnet.*.id}"
    assign_public_ip = true     # Provide the containers with public IPs
    security_groups  = [aws_security_group.http_access_ecs.id]
  }
  
}