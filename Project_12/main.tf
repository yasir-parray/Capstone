terraform {
  required_version = ">= 1.4.0"
}

resource "terraform_data" "project_12" {
  input = {
    project = "Project_12"
    purpose = "CI plan validation"
  }
}
