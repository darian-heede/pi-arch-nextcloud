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



## Basic Maintenance

Log in to nextcloud container with user www-data, activate maintenance mode and perform basic database updates such as adding missing columns and indices. Missing elements can occur after version updates.

```bash
sudo docker exec -it --user=www-data nextcloud-app /bin/sh

php occ maintenance:mode --on

php occ db:add-missing-columns
php occ db:add-missing-indices

# Convert identifiers to BIGINT
php occ db:convert-filecache-bigint

php occ maintenance:mode --off
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
# Or as user www-data
sudo docker exec -it --user=www-data nextcloud-app /bin/sh

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

### Database issue after updating nextcloud major release

After updating the nextcloud container from version 17 to 20 the following error message popped up after running update on the webpage:

> InvalidArgumentException: Column name oc_flow_operations.entity is NotNull, but has empty string or null as default.

The error occured while the database was being updated. It seems there is an issue with the default of column `entity` in table `oc_flow_operations`.

It turns out the column `entity` was missing from the table entirely. Hence, it's necessary to add the column to the table `oc_flow_operations`. The following steps solved the issue:

1. Log into the database container running psql:
`sudo docker exec -it nextcloud-database psql -U postgres`
2. Connect to the nextcloud database (should be default):
`\c postgres`
3. Check if the column is available:
`SELECT entity FROM oc_flow_operations;`
If this command returns
`ERROR:  column "entity" does not exist`
4. Add the column to the table
```sql
ALTER TABLE oc_flow_operations
ADD COLUMN entity VARCHAR NOT NULL;
```
5. Run the Update on the nextcloud webpage.
