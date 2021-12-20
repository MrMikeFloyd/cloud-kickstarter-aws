# Bootstrap template for kickstarting cloud native projects

This project explores bootstrapping a greenfield cloud software project in the quickest possible way. The goal was to find a setup that helps getting into the feedback loop with minimum hassle and little to no self-managed infrastructure. Also, I wanted to keep as many resources as possible (i.e. _all resources_) within AWS to minimise the need for external Repos, Terraform Cloud accounts, etc.

For this example, the following technologies are used:

- An 'as-simple-as-possible' Kotlin-powered Spring Boot project (so that we have something that we can deploy and play around with)
- Docker (for packaging the application)
- AWS CodeCommit/CodeBuild/CodePipeline (for hosting, building, and deploying our application)
- AWS ECR (for storing our container images)
- AWS ECS/Fargate (for running the application with minimum management overhead and to simplify scaling)
- Hashicorp Terraform (for creating and managing all AWS resources)

Terraform remote state information and locking is maintained in S3/DynamoDB.

This sample was built upon Amazon's excellent [ECS/Fargate/Terraform Lab](https://devops-ecs-fargate.workshop.aws/en/).

## Quick setup

Assuming you have your AWS CLI & Git all set up and ready to go, getting the application up and running requires the following steps:

### Initial Setup for Remote State & Locking

1. checkout this project
2. cd into the `terraform/remote-state` directory, run `terraform init`
3. run `terraform apply`

You now have all initial resources to maintain the state of your Terraform stack within AWS.

### Creating the common infrastructure

This sample project uses a central git repo and ci/cd infrastructure. The application stages use the identical container registry to deploy the application from.
In order to create the git repo and all resources for building and storing container images, you need to:

1. cd into the `terraform/common` directory, run `terraform init`
2. run `terraform apply`

### Infrastructure setup

The project is currently prepared for 2 different environments, dev and prod. In order to have a fully functioning environment, you need to apply the infrastructure stack for both environments. If you just want to play around, deploying the `dev` environment is enough. In order to deploy the infrastructure, you need to:

1. cd into the `terraform/infrastructure` directory
2. initialize the `dev` workspace by running `terraform workspace new dev`
3. spin up the environment by running `terraform apply -var-file=./dev.terraform.tfvars`
4. initialize the `prod` workspace by running `terraform workspace new prod`
5. make sure you're in the `prod` workspace by running `terraform workspace list`
6. spin up the environment by running `terraform apply -var-file=./prod.terraform.tfvars`

The infrastructure for maintaining, building, and running your application is now ready. Make sure to note down the `alb_address` output somewhere, you'll need it later to test your application.

### Check in some code and try out the application

1. check the previous stack's outputs for `source_repo_clone_url_http`
2. clone the empty Git repo to a location of your choice
3. copy all contents of the `cloud-bootstap-app` directory into the repo directory
4. commit and push it
5. check the CodePipeline run in the AWS console, optionally have a look at the service events in the ECS console
6. Hit the load balancer's endpoint URL for either of the environments (see `alb_address` stack output from the previous step) - the service should be online (a good idea would be to hit the service's Swagger UI @ `/swagger-ui.html`).
7. Change the application's code on your machine, commit and push, and have the changes built & deployed automagically.

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

From the output of the Terraform build, note the Terraform output `alb_address`, or run `terraform output alb_address`. With it, you should be able to access the application:
- Perform a GET request against the `<your-alb-address-here>/mountains` resource
- Check out the Swagger UI by GETting the `<your-alb-address-here>/swagger-ui.html` resource

### Changing the application and retesting

The pipeline can now be used to deploy any changes to the application. You can try this out by e.g. adding a mountain in the `MountainsController` class, and commiting/pushing the change. The change should become available once the pipeline has run successfully and the changes have been deployed to the ECS cluster.

### Cleanup

In order to tear down the cluster, execute the following commands:

```bash
# compute environments (prod/dev)
cd terraform/infrastructure
terraform workspace select prod
terraform destroy -var-file=./prod.terraform.tfvars
terraform workspace select dev
terraform destroy -var-file=./dev.terraform.tfvars
# ci/cd environment
cd ../common
terraform destroy
# remote state (s3/dynamodb)
cd terraform/remote-state
terraform destroy
```

The created S3 buckets might fail to delete if not empty. In this case, these need to be deleted manually.
