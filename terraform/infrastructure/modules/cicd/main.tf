# ---------------------------------------------------------------------------------------------------------------------
# Code Build
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# Codebuild role
resource "aws_iam_role" "codebuild_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  path = "/"
  tags = {
    Project = var.project
  }
}

resource "aws_iam_policy" "codebuild_policy" {
  description = "Policy to allow codebuild to execute build spec"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
        "ecr:GetAuthorizationToken"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.artifact_bucket.arn}/*"
    },
    {
      "Action": [
        "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability", "ecr:PutImage",
        "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Effect": "Allow",
      "Resource": "${aws_ecr_repository.image_repo.arn}"
    },
    {
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Effect": "Allow",
      "Resource": "${aws_ecr_repository.image_repo.arn}"
    }
  ]
}
EOF
  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy_attachment" "codebuild-attach" {
  role = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}


# Codebuild project
resource "aws_codebuild_project" "codebuild" {
  depends_on = [
    aws_codecommit_repository.source_repo,
    aws_ecr_repository.image_repo
  ]
  name = "codebuild-${var.source_repo_name}-${var.source_repo_branch}"
  service_role = aws_iam_role.codebuild_role.arn
  tags = {
    Project = var.project
  }
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_MEDIUM"
    image = "aws/codebuild/standard:3.0"
    type = "LINUX_CONTAINER"
    privileged_mode = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name = "REPOSITORY_URI"
      value = aws_ecr_repository.image_repo.repository_url
    }
    environment_variable {
      name = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name = "CONTAINER_NAME"
      value = var.family
    }
  }
  source {
    type = "CODEPIPELINE"
    buildspec = <<BUILDSPEC
version: 0.2
runtime-versions:
  java: openjdk8
phases:
  install:
    runtime-versions:
      docker: 18
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=$${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Packaging the application...
      - mvn package
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - printf '[{"name":"%s","imageUri":"%s"}]' $CONTAINER_NAME $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
artifacts:
    files: imagedefinitions.json
BUILDSPEC
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Code Commit
# ---------------------------------------------------------------------------------------------------------------------

# Code Commit repo
resource "aws_codecommit_repository" "source_repo" {
  repository_name = var.source_repo_name
  //default_branch = var.source_repo_branch TODO: This should be 'main', but that'll make the aws provider crash
  description = "Application Git Repository"
  tags = {
    Name = "${var.stack}-Git-Repo"
    Project = var.project
  }
}

# Trigger role and event rule to trigger pipeline
resource "aws_iam_role" "trigger_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  path = "/"
  tags = {
    Project = var.project
  }
}

resource "aws_iam_policy" "trigger_policy" {
  description = "Policy to allow rule to invoke pipeline"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "codepipeline:StartPipelineExecution"
      ],
      "Effect": "Allow",
      "Resource": "${aws_codepipeline.pipeline.arn}"
    }
  ]
}
EOF
  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy_attachment" "trigger-attach" {
  role = aws_iam_role.trigger_role.name
  policy_arn = aws_iam_policy.trigger_policy.arn
}

resource "aws_cloudwatch_event_rule" "trigger_rule" {
  description = "Trigger the pipeline on change to repo/branch"
  event_pattern = <<PATTERN
{
  "source": [ "aws.codecommit" ],
  "detail-type": [ "CodeCommit Repository State Change" ],
  "resources": [ "${aws_codecommit_repository.source_repo.arn}" ],
  "detail": {
    "event": [ "referenceCreated", "referenceUpdated" ],
    "referenceType": [ "branch" ],
    "referenceName": [ "${var.source_repo_branch}" ]
  }
}
PATTERN
  role_arn = aws_iam_role.trigger_role.arn
  is_enabled = true
  tags = {
    Project = var.project
  }

}

resource "aws_cloudwatch_event_target" "target_pipeline" {
  rule = aws_cloudwatch_event_rule.trigger_rule.name
  arn = aws_codepipeline.pipeline.arn
  role_arn = aws_iam_role.trigger_role.arn
  target_id = "${var.source_repo_name}-${var.source_repo_branch}-pipeline"
}

# ---------------------------------------------------------------------------------------------------------------------
# Code Pipeline
# ---------------------------------------------------------------------------------------------------------------------

# Codepipeline role

resource "aws_iam_role" "codepipeline_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  path = "/"
  tags = {
    Project = var.project
  }
}

resource "aws_iam_policy" "codepipeline_policy" {
  description = "Policy to allow codepipeline to execute"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject",
        "s3:GetBucketVersioning"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.artifact_bucket.arn}/*"
    },
    {
      "Action" : [
        "codebuild:StartBuild", "codebuild:BatchGetBuilds",
        "cloudformation:*",
        "iam:PassRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action" : [
        "ecs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action" : [
        "codecommit:CancelUploadArchive",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetUploadArchiveStatus",
        "codecommit:UploadArchive"
      ],
      "Effect": "Allow",
      "Resource": "${aws_codecommit_repository.source_repo.arn}"
    }
  ]
}
EOF
  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy_attachment" "codepipeline-attach" {
  role = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

resource "aws_s3_bucket" "artifact_bucket" {
  tags = {
    Project = var.project
  }
}

# CodePipeline

resource "aws_codepipeline" "pipeline" {
  depends_on = [
    aws_codebuild_project.codebuild,
    aws_codecommit_repository.source_repo
  ]
  name = "${var.source_repo_name}-${var.source_repo_branch}-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type = "S3"
  }
  tags = {
    Name = "${var.stack}-Codepipeline"
    Project = var.project
  }

  stage {
    name = "Source"
    action {
      name = "Source"
      category = "Source"
      owner = "AWS"
      version = "1"
      provider = "CodeCommit"
      output_artifacts = [
        "SourceOutput"]
      run_order = 1
      configuration = {
        RepositoryName = var.source_repo_name
        BranchName = var.source_repo_branch
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      version = "1"
      provider = "CodeBuild"
      input_artifacts = [
        "SourceOutput"]
      output_artifacts = [
        "BuildOutput"]
      run_order = 1
      configuration = {
        ProjectName = aws_codebuild_project.codebuild.id
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name = "Deploy"
      category = "Deploy"
      owner = "AWS"
      version = "1"
      provider = "ECS"
      run_order = 1
      input_artifacts = [
        "BuildOutput"]
      configuration = {
        ClusterName = "${var.stack}-Cluster"
        ServiceName = "${var.stack}-Service"
        FileName = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ECR Container Repo
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecr_repository" "image_repo" {
  name = var.image_repo_name
  image_tag_mutability = "MUTABLE"
  tags = {
    Name = "${var.stack}-ECR-Container-Repo"
    Project = var.project
  }
}
