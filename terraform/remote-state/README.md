# Terraform remote state setup

In order for Terraform to store and maintain its state and locks remotely (and keeping everything in AWS), this module creates an S3 bucket and a DynamoDB table.

## What resources do I get?

You'll get 2 S3 buckets and 2 DynamoDB tables, one for the common stack and one for the env-aware infrastructure stack.

## How to set up

Before applying the infrastructure stack, apply this one:

```hcl
terraform init
terraform apply
```

That's it. Once this is done, you may proceed and apply the infrastructure stack.
