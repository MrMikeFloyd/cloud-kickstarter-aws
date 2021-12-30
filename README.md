# Bootstrap template for kickstarting cloud native projects

This project explores bootstrapping a greenfield cloud software project in the quickest possible way. The goal was to find a setup that helps to get into the feedback loop with minimum hassle and little to no self-managed infrastructure. Also, I wanted to keep as many resources as possible (i.e. _all resources_) within AWS to minimise the need for external Repos, Terraform Cloud accounts, etc.

## What's in the box?

This project comes with

- a terraform stack that builds a dev and prod compute environment in AWS with automated ci/cd and blue/green deployment
- a sample application with a http endpoint so we have something to play around with

## What technologies/AWS services are used?

I'm using the following technologies and services:

- Hashicorp Terraform (for creating and managing all AWS resources)
- An 'as-simple-as-possible' Kotlin-powered Spring Boot project (so that we have something that we can deploy and play around with)
- Docker (for packaging the application)
- AWS CodeCommit/CodeBuild/CodePipeline/CodeDeploy (for hosting, building, and deploying our application)
- AWS ECR (for storing our container images)
- AWS ECS/Fargate (for running the application with minimum management overhead and to simplify scaling)

Terraform remote state information and locking is maintained in S3/DynamoDB.

This sample was built with the help of Amazon's excellent labs and workshops on ECS and CI/CD:

- [ECS/Fargate/Terraform Lab](https://devops-ecs-fargate.workshop.aws/en/)
- [CI/CD workshop for Amazon ECS](https://catalog.us-east-1.prod.workshops.aws/v2/workshops/869f7eee-d3a2-490b-bf9a-ac90a8fb2d36/en-US)

## Quick setup

In order to run this sample, you'll need:

- An AWS account
- The [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- Git

The detailed setup steps for setting up the AWS CLI and Terraform can be found below. 
Assuming you have everything set up and ready to go, running this sample involves the following steps:

### Initial Setup for Remote State & Locking

1. checkout this project
2. cd into the `terraform/remote-state` directory, run `terraform init`
3. run `terraform apply`

You now have all initial resources to maintain the state of your Terraform stack within AWS (S3 & DynamoDB).

### Infrastructure setup

1. cd into the `terraform/infrastructure` directory, run `terraform init`
2. run `terraform apply`

The infrastructure for maintaining, building, deploying, and running your application is now ready. Pay attention to the stack's output, mainly `source_repo_clone_url_http` and `ecs_task_execution_role_arn_prod`, you will need these in the next step.

### Prepare the application and trigger blue/green deployment to production

1. Use the previous stack's output (`source_repo_clone_url_http`) and use `git clone <url>` to clone it to a location of your choice
2. copy all contents of the `cloud-bootstap-app` directory into the empty repo directory, then `cd` into it
3. Create your own ecs task definition by duplicating the template file (`taskdef-prod.json.template`) and filling in your execution role's arn:

```shell
# make sure to perform this step in your cloned application repo from step 1 & 2
export TASK_EXEC_ROLE_ARN=<arn-from-tf-output>
envsubst < taskdef-prod.json.template > taskdef-prod.json
```

4. commit and push the changes
5. check the ci/cd execution in the [CodePipeline console](https://console.aws.amazon.com/codepipeline), optionally have a look at the service events in the [ECS console](https://console.aws.amazon.com/ecs) to observe the deployment process
6. Hit the load balancer's endpoint URL (see `alb_address_dev` stack output) - the service should be online (a good idea would be to hit the service's Swagger UI @ `/swagger-ui.html`).
7. Change the application's code on your machine (maybe add a mountain in `MountainsController.kt`?), commit and push
8. Check the [CodePipeline console](https://console.aws.amazon.com/codepipeline) again. upon successful deployment to DEV, there is a manual approval step that you'll need to confirm in order to trigger the PROD deployment
9. Upon approval, the blue/green deployment to PROD is triggered. Observe it in the [CodeDeployment console](https://console.aws.amazon.com/codedeploy) and the [ECS console](https://console.aws.amazon.com/ecs). Deployment should take a few minutes.
10. Verify that the changes have actually been deployment to production by `curl`ing the application's PROD endpoint (see `alb_address_prod` stack output)

That's it.

Should you run into any errors along the way, please have a look at the initial setup steps below. Also, please don't forget to teardown everything when you've played around enough to avoid unnecessary cost.

## Detailed Setup

The following section dives deeper into the steps required to get started.

### Configuring the AWS CLI

Configure the AWS CLI to match the desired region:

```bash
aws configure
AWS Access Key ID [None]: 
AWS Secret Access Key [None]: 
Default region name [None]: eu-central-1
Default output format [None]: 
```

### Adjust Terraform variables

```bash
cd terraform/infrastructure
```

Edit `terraform.tfvars`, leave the `aws_profile` as `"default"`, and set `aws_region` to match your needs. 

### Terraform stack resources

The following resources will be created by terraform:

- S3 buckets for terraform state and build artifacts - view it in the [S3 console](https://s3.console.aws.amazon.com/s3).
- DynamoDB table for terraform state locking - view it in the [DynamoDB console](https://s3.console.aws.amazon.com/dynamodb).
- ALB - view it in the [EC2 console](https://console.aws.amazon.com/ec2).
- ECS cluster - view it in the [ECS console](https://console.aws.amazon.com/ecs).
- ECR container registry - view it in the [ECR console](https://console.aws.amazon.com/ecr).
- CodeCommit git repo - view it in the [CodeCommit console](https://console.aws.amazon.com/codecommit).
- CodeBuild project - view it in the [CodeBuild console](https://console.aws.amazon.com/codebuild).
- CodePipeline build pipeline - view it in the [CodePipeline console](https://console.aws.amazon.com/codepipeline).
- CodeDeploy blue/green deployment - view it in the [CodeDeploy console](https://console.aws.amazon.com/codedeploy).

### Local Git setup

In order to be able to interact with the CodeCommit repo created by this terraform stack, please make sure to setup your git installation appropriately. You will need to set the codecommit `credential-helper` for things to run smoothly.

```bash
git config --global user.name "John Doe" # you might have set this up already
git config --global user.email jdoe@thisismyemail.com # same here
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

You should now be able to clone the CodeCommit Repo to a local directory of your choice. The repo URL can be found looking at the terraform outputs of the stack, see `source_repo_clone_url_http` or run `terraform output source_repo_clone_url_http`.

**macOS users**: In case you encounter weird HTTP 403 errors when cloning, please look at any previously stored CodeCommit credentials in your Keychain Access app, and delete them.

### Testing the application

From the output of the Terraform build, note the Terraform output `alb_address_dev` (dev stage) and `alb_address_prod` (prod stage), or run `terraform output alb_address_<stage>`. With it, you should be able to access the application:
- Perform a GET request against the `<your-alb-address-here>/mountains` resource
- Check out the Swagger UI by GETting the `<your-alb-address-here>/swagger-ui.html` resource

### Changing the application and retesting

Testing the deployment process can best be tested by changing the application and observing how these end up in the respective stages. You can try this out by e.g. adding a mountain in the `MountainsController` class, and committing/pushing the change. This will trigger the following:

- Automated deployment to the ECS dev cluster stage
- Automated blue/green deployment to production. This requires a *manual approval* step in CodePipeline after the deployment to the dev stage completed successfully

### Cleanup

In order to tear down the cluster, execute the following commands:

```bash
cd terraform/infrastructure
terraform destroy
cd terraform/initial-setup/remote-state
terraform destroy
```

The created S3 buckets might fail to delete if not empty. In this case, these need to be deleted manually.
