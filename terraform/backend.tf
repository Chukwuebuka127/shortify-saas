 terraform {
  backend "s3" {
    bucket       = "shortify-tfstate-emmanuel127"
    key          = "shortify/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}


