terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.80"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.80"
    }
  }
}

provider "google" {
  project = var.foundation_project_id
  region  = var.default_region
}

provider "google-beta" {
  project = var.foundation_project_id
  region  = var.default_region
}
