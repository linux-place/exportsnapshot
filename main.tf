# provider "aws" {
#   region = var.aws_region
# }

locals {
  environment = merge({ S3_BUCKET = var.export_bucket,
    DB_CLUSTER_ID = var.db_cluster_id,
    IAM_ROLE      = var.iam_role,
    KMS_KEY       = var.kms_key,
    EXPORT_ID     = var.export_id,
    TABLE_LIST    = var.tables,
    FORCE_LAST    = var.force_last
    },
  var.environment_variables)
}

# Cloudwatch event rule
resource "aws_cloudwatch_event_rule" "check-scheduler-event" {
  name                = "${var.function_name}-check-scheduler-event"
  description         = "check-scheduler-event"
  schedule_expression = var.schedule_expression
  depends_on          = [module.lambda_function.this_lambda_function_arn]
}

# Cloudwatch event target
resource "aws_cloudwatch_event_target" "check-scheduler-event-lambda-target" {
  rule      = aws_cloudwatch_event_rule.check-scheduler-event.name
  arn       = module.lambda_function.this_lambda_function_arn
}


resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = module.lambda_function.this_lambda_function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.check-scheduler-event.arn
}


module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.function_name
  description   = "Export database to s3"
  handler       = "index.instantiate_s3_export"
  runtime       = "python3.8"
  publish       = true

  source_path = "${path.module}/src/export_snap_s3"

  # layers = [
  #   module.lambda_layer_boto3.this_lambda_layer_arn,
  # ]

  environment_variables = local.environment

  attach_policy_jsons = true
  policy_jsons = [<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${var.export_bucket}*/*",
                "arn:aws:s3:::${var.export_bucket}"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets"
            ],
            "Resource": "*"
        },
        {
          "Sid": "DBSnapshots",
          "Effect": "Allow",
          "Action": [
            "rds:DescribeDBClusterSnapshots",
            "rds:DescribeDBClusters",
            "rds:DescribeDBInstances",
            "rds:DescribeDBSnapshots",
            "rds:StartExportTask"
          ],
          "Resource": "*"
        },{
          "Sid": "IAM",
          "Effect":"Allow",
          "Action":[
            "iam:PassRole"
          ],
          "Resource": "${var.iam_role}"
        },
        {   
            "Sid": "KMS",
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey",
                "kms:CreateGrant"
            ],
            "Resource": "${var.kms_key}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:DescribeKey"
            ],
            "Resource":"*"
        }
    ]
}
EOF
  ]
  number_of_policy_jsons = 1

  tags = {
    Module = "lambda-with-layer"
  }
}

# module "lambda_layer_boto3" {
#   source = "terraform-aws-modules/lambda/aws"

#   create_layer = true

#   layer_name          = "boto3"
#   description         = "boto3"
#   compatible_runtimes = ["python3.8"]

#   source_path = "layers/python"

# }