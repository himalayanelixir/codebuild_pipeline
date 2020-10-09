terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region                  = var.region
  shared_credentials_file = var.credentials
}

resource "random_pet" "pets" {
  length = 1
  prefix = var.prefix
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = "${random_pet.pets.id}-codepipeline-bucket"
  acl           = "private"
  force_destroy = true
}

resource "aws_s3_bucket" "source_bucket" {
  bucket        = "${random_pet.pets.id}-source-bucket"
  acl           = "private"
  force_destroy = true
  versioning {
    enabled = true
  }
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "source"
  output_path = ".output/source.zip"
}

resource "aws_s3_bucket_object" "source_zip" {
  bucket = aws_s3_bucket.source_bucket.id
  key    = "source.zip"
  source = data.archive_file.source.output_path
  etag   = data.archive_file.source.output_md5
}

resource "aws_codebuild_project" "codebuild_project" {
  name          = "${random_pet.pets.id}-codebuild-project"
  description   = "CodeBuild project"
  build_timeout = "60"
  service_role  = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${random_pet.pets.id}-codepipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      output_artifacts = ["SourceArtifact"]
      version          = "1"
      configuration = {
        S3Bucket    = aws_s3_bucket.source_bucket.bucket
        S3ObjectKey = "source.zip"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project.id
      }
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${random_pet.pets.id}-codepipeline-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "${random_pet.pets.id}-codepipeline-policy"
  role   = aws_iam_role.codepipeline_role.name
  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "s3:ListBucket",
          "s3:ListObjects",
          "s3:Get*",
          "s3:PutObject*",
          "s3:PutBucket*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source_bucket.arn}",
        "${aws_s3_bucket.source_bucket.arn}/*",
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Action": [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_codebuild_project.codebuild_project.arn}"
      ]
    }
  ]
}
EOF
}
resource "aws_iam_role" "codebuild_role" {
  name               = "${random_pet.pets.id}-codebuild-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "${random_pet.pets.id}-codebuild-policy"
  role   = aws_iam_role.codebuild_role.name
  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.codebuild_project.name}:*"
      ]
    },
    {
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    },
    {
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    }
  ]
}
EOF
}