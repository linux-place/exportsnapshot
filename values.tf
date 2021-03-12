variable "export_bucket" {
  type = string
}
variable "db_cluster_id" {
  type = string
}
variable "iam_role" {
  type = string
}
variable "export_id" {
  type = string
}
variable "kms_key" {
  
}
variable "tables" {
  type    = string
  default = ""
}

variable "schedule_expression" {
  type = string
  
}
variable "function_name" {
  type = string
  default = "export_to_s3"
  
}

# variable "aws_region" {
#   type    = string
#   default = "us-east-1"
# }

variable "environment_variables" {
  default     = {}
  description = "Variables"
  type        = map(string)
}

variable "tags" {
  type    = map
  default = {}
}
