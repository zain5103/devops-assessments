# EC2 High CPU Utilization Alarm (Targeting Jenkins Agent)
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "${var.environment}-ec2-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors EC2 CPU utilization exceeding 80%"

  dimensions = {
    InstanceId = aws_instance.jenkins_agent.id
  }
}

# ALB 5XX Error Rates Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.environment}-alb-high-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alarm triggers if ALB receives more than 5 5XX errors in 1 minute"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
