// Instantiate a minimal version of the module for testing
provider "aws" {
  region = "us-east-1"
}

resource "random_id" "testing_suffix" {
  byte_length = 4
}

//Create a logging bucket specifically for this test to support shipping of the access logs produced by the it_minimal bucket
resource "aws_s3_bucket" "log_bucket" {
  bucket        = "qm-test-log-${random_id.testing_suffix.hex}"
  acl           = "log-delivery-write"
  force_destroy = "true"
}

module "it_minimal" {
  source = "../../../" //minimal integration test

  logical_name = "${var.logical_name}-${random_id.testing_suffix.hex}"
  region       = "${var.region}"

  logging_target_bucket = "${aws_s3_bucket.log_bucket.id}"

  org   = "${var.org}"
  owner = "${var.owner}"
  env   = "${var.env}"
  app   = "${var.app}"
}

resource "null_resource" "before" {}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  triggers = {
    "before" = "${null_resource.before.id}"
  }
}

resource "aws_kms_key" "a" {
  description = "Key for testing tf_s3_bucket infra and secure-by-default policy"
}

resource "aws_kms_alias" "a" {
  name          = "alias/tf_s3_bucket"
  target_key_id = "${aws_kms_key.a.key_id}"
}

resource "aws_s3_bucket_object" "test" {
  bucket       = "${module.it_minimal.s3.id}"
  key          = "aws_kms_key"
  content_type = "application/json"
  content      = "{message: 'hello world'}"
  depends_on   = ["null_resource.delay"]
}

variable "logical_name" {
  type = "string"
}

variable "region" {
  type = "string"
}

variable "org" {
  type = "string"
}

variable "owner" {
  type = "string"
}

variable "env" {
  type = "string"
}

variable "app" {
  type = "string"
}

output "module_under_test.bucket.id" {
  value = "${module.it_minimal.s3.id}"
}
