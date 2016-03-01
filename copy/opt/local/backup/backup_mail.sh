#!/bin/sh

INCREMENTS="$(mdata-get backup:increments || echo 28)"
RETAIN_FULL="$(mdata-get backup:retain || echo '8 weeks')"

OPENSSL_KEY="$(mdata-get backup:openssl_key)"
OPENSSL_IV="$(mdata-get backup:openssl_iv)"

GS_BUCKET="$(mdata-get backup:bucket)"

# Override these values in the file sourced below if needed
TAR=/opt/local/bin/gtar
GSUTIL=/opt/local/bin/gsutil
BACKUP_DIR=/srv/mail/backup
MAIL_DIR=/srv/mail

[ -f "${BACKUP_DIR}/settings.sh" ] && source ${BACKUP_DIR}/settings.sh

# Exit if the required info isn't available
[ -z "$OPENSSL_KEY" ] && exit 1
[ -z "$OPENSSL_IV" ] && exit 1
[ -z "$GS_BUCKET" ] && exit 1

# Create backup dest dir if nonexistent
[ ! -d "${BACKUP_DIR}" ] && mkdir -p "${BACKUP_DIR}"
[ ! -d "${BACKUP_DIR}/.snapshots" ] && mkdir -p "${BACKUP_DIR}/.snapshots"

# Check if we need to do a full backup
snapshotdir="${BACKUP_DIR}/.snapshots"
cursnapfile="${snapshotdir}/.current"
date=$(date +%Y-%m-%d)
if [ ! -f "${cursnapfile}.snap" ]; then
        # There is no data, start at 0
        cursnap=0
else 
        cursnap=$(cat "${cursnapfile}.snap")
        if [ "$cursnap" -ge "${INCREMENTS}" ]; then
                cursnap=0
        else
                # Copy the previous snapshot file to the current file, to be used later
                cp "${snapshotdir}/snapshot.${cursnap}" "${snapshotdir}/snapshot.$((++cursnap))"
        fi
fi

# If we're at 0, remove the old snapshot files and save the date
if [ "${cursnap}" -eq "0" ]; then
        rm "${snapshotdir}/snapshot.*"
        echo "${date}" > "${cursnapfile}.date"
fi

echo "${cursnap}" > "${cursnapfile}.snap"

# Back the fuck up.
cd "${MAIL_DIR}"
for domain in domains/*; do
	d=$(basename "${domain}")
        ${TAR} --listed-incremental="${snapshotdir}/snapshot.${cursnap}" -cvz "domains/${d}" "passwd/${d}" | openssl aes-128-cbc -K "${OPENSSL_KEY}" -iv "${OPENSSL_IV}" -e -out "${BACKUP_DIR}/${d}.tgz.aes"

        # Send to Google
        prev_date=$(cat ${cursnapfile}.date)
        ${GSUTIL} cp ${BACKUP_DIR}/${d}.tgz.aes ${GS_BUCKET}/${prev_date}/${d}.${cursnap}.tgz.aes
done

# Also back up data like users/passwds and whatnot.
${TAR} cvz aliases dkim ssl dovecot exim/conf | openssl aes-128-cbc -K "${OPENSSL_KEY}" -iv "${OPENSSL_IV}" -e -out "${BACKUP_DIR}/data.tgz.aes"
${GSUTIL} cp ${BACKUP_DIR}/data.tgz.aes ${GS_BUCKET}/${prev_date}/${date}_data.tgz.aes

# Clean old remote backups older than $RETAIN
${GSUTIL} ls ${GS_BUCKET} | while read line; do 
        date=$(echo "$line" | cut -d/ -f4)
        stamp=$(date -d "$date" +%s);
        comp=$(date -d "now - ${RETAIN_FULL}" +%s);
        if [ $stamp -le $comp ]; then
                ${GSUTIL} rm -r "$line"
        fi;
done
