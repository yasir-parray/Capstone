terraform {
  required_version = ">= 1.4.0"
}

resource "terraform_data" "project_06" {
  input = {
    project        = "Project_06"
    tracked_change = "initial"
  }
}

output "tracked_change" {
  value = terraform_data.project_06.output.tracked_change
}
