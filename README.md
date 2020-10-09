# CodeBuild Pipeline

Simple two stage CodePipeline with S3 source stage and CodeBuild build stage. Everything provisioned through Terraform. Just run `terraform init`,
`terraform plan`, and if everything looks good to you `terraform apply`.

Running `terraform destroy` will take down all the resources that are created including the S3 buckets with objects in them.
