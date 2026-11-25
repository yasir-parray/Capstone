#!/bin/bash
dnf install -y httpd || yum install -y httpd
echo "<h1>Project 21 CloudWatch Monitored Host (yasir-p21)</h1>" > /var/www/html/index.html
systemctl enable --now httpd
