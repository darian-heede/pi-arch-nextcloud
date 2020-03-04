# pi-arch-nextcloud

Nextcloud configuration for the raspberry pi 3 B (+) using docker nginx-fpm and local letsencrypt certbot.

## Environment files

Environment files need to be placed in root folder.

### `.env`
```bash
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<postgres-pwd>
POSTGRES_HOST=db
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=<nextcloud-admin-pwd>
NEXTCLOUD_TRUSTED_DOMAINS=<your-nextcloud.domain>
HOST=<your-nextcloud.domain>
```

### `app.env`
```bash
VIRTUAL_HOST=<your-nextcloud.domain>
LETSENCRYPT_HOST=<your-nextcloud.domain>
LETSENCRYPT_EMAIL=<email>
```

### `db.env`
```bash
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<postgres-pwd>
```

## Troubleshooting

### SSL encryption

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

### Connect to nextcloud-client on desktop

Granting access send token to `http` endpoint rather than `https` per default, resulting in access not being granted. To fix this, the `config/config.php` file must be edited on the `nextcloud-app` container:

```bash
sudo docker exec -it nextcloud-app /bin/sh
vi config/config.php
```

Add the following lines to the `config.php`:

```bash
[...]
'overwrite.cli.url' => 'https://<your-nextcloud.domain>',
'overwritehost' => '<your-nextcloud.domain>',
'overwriteprotocol' => 'https'
[...]
```

After doing this, the client can have access granted.