# pi-arch-nextcloud

Nextcloud configuration for the raspberry pi 3 B (+) using docker nginx-fpm and local letsencrypt certbot.

## Troubleshooting

`jrcs/letsencrypt-nginx-proxy-companion` is not availabe for arm architecture. `alexanderkrause/rpi-letsencrypt-nginx-proxy-companion` does not support ACMEv2 (as of yet). Fallback is to use certbot on server and linking the certificates as volume for proxy container.

```bash
# Install necessary packages
sudo pacman -S nginx certbot certbot-nginx cronie

# Have certbot generate certificates
sudo sudo certbot certonly --nginx

# Enable and start cronie service
sudo systemctl enable cronie.service
sudo systemctl start cronie.service

# Add automatic renewal cron job to crontab
echo "0 0,12 * * * root python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew" | sudo tee -a /etc/crontab > /dev/null

# Stop local nginx from blocking port 80
sudo nginx -s stop
```

Generate Diffie-Hellman parameter file

```bash
sudo openssl dhparam -dsaparam -out /etc/nginx/dhparam/dhparam.pem 4096
```

