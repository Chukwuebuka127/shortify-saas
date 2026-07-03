terraform {
  backend "s3" {
    bucket         = "shortify-tfstate-emmanuel127"
    key            = "shortify/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "shortify-tf-locks"
    encrypt        = true
  }
}
