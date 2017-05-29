#!/bin/sh

INCREMENTS="$(mdata-get backup:increments || echo 28)"
RETAIN_FULL="$(mdata-get backup:retain || echo '8 weeks')"

OPENSSL_KEY="$(mdata-get backup:openssl_key)"

GS_BUCKET="$(mdata-get backup:bucket)"

# Override these values in the file sourced below if needed
TAR=/opt/local/bin/gtar
# Reprovisioning causes device numbers of delegated datasets to change, so we need
# to tell tar to ignore that.
TAR_OPTIONS="--no-check-device"
GSUTIL=/opt/local/bin/gsutil
BACKUP_DIR=/srv/mail/backup
MAIL_DIR=/srv/mail

export TAR_OPTIONS

[ -f "${BACKUP_DIR}/settings.sh" ] && source ${BACKUP_DIR}/settings.sh

# Exit if the required info isn't available
[ -z "$OPENSSL_KEY" ] && exit 1
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
        prevsnap=$(cat "${cursnapfile}.snap")
        if [ "$prevsnap" -ge "${INCREMENTS}" ]; then
                cursnap=0
        else
                cursnap=$((prevsnap+1))
        fi
fi

# If we're at 0, remove the old snapshot files and save the date
if [ "${cursnap}" -eq "0" ]; then
        rm "${snapshotdir}"/snapshot.*
        echo "${date}" > "${cursnapfile}.date"
fi

# Back the fuck up.
cd "${MAIL_DIR}"
for domain in domains/*; do
        for user in ${domain}/*; do
                d=$(basename "${domain}")
                u=$(basename "${user}")

                ${TAR} --listed-incremental="${snapshotdir}/snapshot.${d}-${u}.snar" -cvz "domains/${d}/${u}" | openssl aes-128-cbc -k "${OPENSSL_KEY}" -e -out "${BACKUP_DIR}/${d}-${u}.tgz.aes"

                # Send to Google
                prev_date=$(cat ${cursnapfile}.date)
                ${GSUTIL} cp ${BACKUP_DIR}/${d}-${u}.tgz.aes ${GS_BUCKET}/${prev_date}/${d}/${u}.${cursnap}.tgz.aes
        done
done

# Save state.
echo "${cursnap}" > "${cursnapfile}.snap"

# Also back up data like users/passwds and whatnot.
${TAR} cvz passwd aliases dkim ssl dovecot exim/conf | openssl aes-128-cbc -k "${OPENSSL_KEY}" -e -out "${BACKUP_DIR}/data.tgz.aes"
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

