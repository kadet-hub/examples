# The same bucket and ConfigMap with Terraform alone: the bucket name reaches
# Kubernetes through a reference, once per way of writing the ConfigMap.
terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "6.69.1" }
    kubernetes = { source = "hashicorp/kubernetes", version = "3.4.0" }
    helm       = { source = "hashicorp/helm", version = "3.3.0" }
  }
}

variable "bucket" {
  type    = string
  default = "example-shop-uploads-prod"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "helm_manifest" {
  type    = bool
  default = false
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {}

provider "helm" {
  experiments = { manifest = var.helm_manifest }
}

resource "aws_s3_bucket" "uploads" {
  bucket = var.bucket
}

resource "kubernetes_config_map_v1" "web" {
  metadata {
    name      = "web"
    namespace = "shop"
  }
  data = {
    bucket = aws_s3_bucket.uploads.bucket
    region = aws_s3_bucket.uploads.region
  }
}

resource "kubernetes_manifest" "web" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata   = { name = "web-manifest", namespace = "shop" }
    data = {
      bucket = aws_s3_bucket.uploads.bucket
      region = aws_s3_bucket.uploads.region
    }
  }
}

resource "helm_release" "web" {
  name      = "web"
  namespace = "shop"
  chart     = "${path.module}/chart"
  set = [
    { name = "bucket", value = aws_s3_bucket.uploads.bucket },
    { name = "region", value = aws_s3_bucket.uploads.region },
  ]
}
