data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

#====================================

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "cloudacademy-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy" "amazon_ec2_container_service_for_ec2_role" {
  name = "AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.amazon_ec2_container_service_for_ec2_role.arn
}

resource "aws_iam_role_policy" "secretsmanager_policy" {
  name = "password-policy-secretsmanager"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Effect": "Allow",
        "Resource": [
          "${var.secretsmanager_db_creds_arn}"
        ]
      }
    ]
  }
  EOF
}

#====================================

resource "aws_iam_role" "ecs_exec_task_role" {
  name               = "cloudacademy-ecs-exec-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy" "amazon_ssm_managed_instance_core" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_role_policy_attach" {
  role       = aws_iam_role.ecs_exec_task_role.name
  policy_arn = data.aws_iam_policy.amazon_ssm_managed_instance_core.arn
}
