terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
  shared_credentials_file = "/Users/ramababu.bendalam/.aws/credentials"
  profile                 = "experiment"
}

module "my_instance_module" {
        source = "./modules"
        s3BucketName = "mytest-digitech-copyfiles"
        aws_region = "eu-west-2"
        apiGatewayName = "digitechApi"
        apiKeyName = "digitechKey"
}



