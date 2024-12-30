#!/bin/bash

boto_token=$(mdata-get boto:gs_oauth2_refresh_token || true)
boto_project_id=$(mdata-get boto:default_project_id || true)

if [ ! -z "$boto_token" ] && [ ! -z "$boto_project_id" ]; then
cat <<EOF > /etc/boto.cfg
[Credentials]
gs_oauth2_refresh_token = ${boto_token}
[Boto]
https_validate_certificates = True
[GSUtil]
content_language = en
default_api_version = 2
default_project_id = ${boto_project_id}
EOF
fi

# Add a crontab entry
echo '23 4 * * * /opt/local/backup/backup_mail.sh' >> /etc/cron.d/crontabs/root
