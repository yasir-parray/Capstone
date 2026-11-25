#!/bin/bash

apt update -y
apt install apache2 -y

echo "<h1>Yasir Project 16 HTTPS Demo</h1><h3>Yasir Mohi ud din</h3>" > /var/www/html/index.html

systemctl enable apache2
systemctl start apache2
