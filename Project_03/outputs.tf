output "instance_id" {
  value = aws_instance.project.id
}

output "public_ip" {
  value = aws_instance.project.public_ip
}

output "cpu_alarm_name" {
  value = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}