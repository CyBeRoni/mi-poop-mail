#!/bin/bash

. /srv/mail/ssl/dehydrated/config.d/cf_api.sh

log() {
	echo "   $*" 1>&2
}

success() {
	echo " + $*" 1>&2
}

error() {
	echo "ERROR: $*" 1>&2
}

# exit inside a $() does not work, so we will roll out our own
scriptexitval=1
trap "exit \$scriptexitval" SIGKILL
abort() {
	scriptexitval=$1
	kill 0
}

if which drill &>/dev/null; then
	resolve_record() {
		drill "$1" "$2" @ns.cloudflare.com | sed -rn "s/^.*?\.\t[0-9]+\tIN\t$2\t//p"
	}
elif which dig &>/dev/null; then
	resolve_record() {
		dig +short "$1" "$2" @ns.cloudflare.com
	}
else
	echo "No DNS lookup tool installed. Please install either dig or drill"
	abort 1
fi

cf_req() {
	local response
	if [ ! -z "${CF_TOKEN}" ]; then
		response=$(curl -s -H "Authorization: Bearer ${CF_TOKEN}" -H "Content-Type: application/json" $*)
	elif [ ! -z "${CF_EMAIL}" ] && [ ! -z "${CF_KEY}" ]; then
		response=$(curl -s -H "X-Auth-Email: ${CF_EMAIL}" -H "X-Auth-Key: ${CF_KEY}" -H "Content-Type: application/json" $*)
	else
		error "Missing CF keys"
		abort 1
	fi
	if [ $? -ne 0 ]; then
		error "HTTP request failed"
		abort 1
	fi

	local success=$(echo "$response" | jq -r ".success")
	if [ "$success" != true ]; then
		error "CloudFlare request failed"
		error "Response: $response"
		abort 1
	fi

	echo "$response"
}


get_zone_id() {
	local fqdn="$1"

	id=$(grep "^${fqdn}" /srv/mail/ssl/dehydrated/cf_zones.txt | cut -d' ' -f2)

	success "Zone ID: $id"

	echo "$id"
}

wait_for_publication() {
	local fqdn="$1"
	local type="$2"
	local content="$3"

	local retries=12
	local delay=1000
	local delaySec

	while true; do
		if resolve_record "$fqdn" "$type" | grep -qF "$content"; then
			return
		fi

		if [ $retries -eq 0 ]; then
			error "Record $fqdn did not get published in time"
			abort 1
		else
			delaySec=${delay:0:(-3)}.${delay:(-3)}
			log "Waiting $delaySec seconds..."
			sleep $delaySec

			retries=$(($retries - 1))
			delay=$(($delay * 15 / 10))
		fi
	done
}

create_record() {
	local zone="$1"
	local fqdn="$2"
	local type="$3"
	local content="$4"
	local recordid

	log "Creating record $fqdn $type $content"

	recordid=$(cf_req -X POST "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records" \
		--data "{\"type\":\"${type}\",\"name\":\"${fqdn}\",\"content\":\"${content}\"}" |
		jq -r ".result.id")

	if [ "$recordid" == null ]; then
		error "Error creating DNS record"
		abort 1
	fi

	echo "$recordid"
}

list_record_id() {
	local zone="$1"
	local fqdn="$2"

	cf_req "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records?name=${fqdn}" |
	jq -r ".result[] | .id"
}

delete_records() {
	local zone="$1"
	local fqdn="$2"

	log "Deleting record(s) for $fqdn"

	list_record_id "$zone" "$fqdn" |
	while read recordid; do
		log " - Deleting $recordid"
		cf_req -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records/${recordid}" >/dev/null
	done
}

deploy_challenge() {
	local fqdn="$2"
	local token="$4"
	local zoneid=$(get_zone_id "$fqdn")

	recordid=$(create_record "$zoneid" "_acme-challenge.$fqdn" TXT "$token")
	wait_for_publication "_acme-challenge.$fqdn" TXT "\"$token\""

	success "challenge created - CF ID: $recordid"
}

clean_challenge() {
	local fqdn="$2"
	local zoneid=$(get_zone_id "$fqdn")

	delete_records "$zoneid" "_acme-challenge.$fqdn"
}

case $1 in
	deploy_challenge)
		deploy_challenge $*
		;;

	clean_challenge)
		clean_challenge $*
		;;
esac
