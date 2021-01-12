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



## Upgrade nextcloud version using cli

The following steps upgrade the nextcloud instance to a new stable version

```bash
# Login to container
sudo docker exec -it --user=www-data nextcloud-app /bin/sh

# Run updater.phar
php updater/updater.phar

# Run occ upgrade
php occ upgrade

# If maintenance mode is still active, turn it off
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

### `crontab` won't run

The `busybox` binary needs stickybit to use crontab (and more) for the non root nextcloud user `www-data`. This is the case if `crontab -l` returns `crontab: must be suid to work properly` when called b y user `www-data`.

```bash
# Login as root and activate maintenance mode
sudo docker exec -it nextcloud-app /bin/sh
php occ maintenance:mode --on

# Check permissions for crontab and busybox
ls -al /bin/crontab
ls -al /bin/busybox

# Add stickybit to busybox binary
chmod u+s /bin/busybox

# Exit root and login as www-data
exit
crontab -l
sudo docker exec -it --user=www-data nextcloud-app /bin/sh

# Deactivate maintenance mode
php occ maintenance:mode --on
```

### Updater folder missing

An installation or update has gone awry leaving the crucial `updater` folder missing from the nextcloud root `/var/www/html/`. This leads to a 404 error when trying to update via the admin settings.

```bash
# Load the current stable nextcloud archive
cd /tmp
wget https://download.nextcloud.com/server/releases/nextcloud-20.0.4.zip

# Unpack relevant files
unzip -j nextcloud-20.0.4.zip nextcloud/updater/*

# Copy files to docker container
sudo docker cp /tmp/index.php nextcloud-app:/var/www/html/updater/
sudo docker cp /tmp/updater.phar nextcloud-app:/var/www/html/updater/

# Login as root and set correct permissions
sudo docker exec -it nextcloud-app /bin/sh

chown -R www-data:www-data /var/www/html/updater/
```



