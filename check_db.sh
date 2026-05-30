#!/bin/bash
sudo -u postgres psql pakiip_db -c "SELECT service_fee FROM app_config LIMIT 1;"
echo "---ORDERS---"
sudo -u postgres psql pakiip_db -c "SELECT order_code, total, delivery_fee, service_fee, tip, items FROM orders ORDER BY created_at DESC LIMIT 3;"
