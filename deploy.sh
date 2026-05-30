#!/bin/bash
cd /home/ubuntu/pakiip/backend
git pull origin main 2>/dev/null || true
pm2 restart pakiip-api
echo "Reiniciado exitosamente"
pm2 status
