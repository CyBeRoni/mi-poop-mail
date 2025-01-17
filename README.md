mi-poop-mail
==========

This is a machine image for an e-mail server based on Exim, Dovecot, Clamav and Spamassassin. It is
suitable mostly for low to medium-volume use, such as for personal use or a small business.

Use with minimal-64 image from SmartOS as a base; tested with minimal-64-trunk 20240116

To use: create a zone with above-mentined image, get this code onto it (curl the tarball from Github),
execute the `customize` script and upon completion follow the instructions to create an image from 
https://docs.smartos.org/managing-images/#creating-a-custom-zone-image.


Metadata
--------
The following customer_metadata is used:

* dovecot:qualify_domain - Domain to use as the authentication realm if the client presents none (default: none)
* dovecot:primary_hostname - Hostname to use for TLS (default: system hostname)
* exim:qualify_domain: - Domain to append to addresses when only a local_part is given
* system:ssh_disabled - Whether or not to disable the ssh daemon (default: false)
* system:timezone - What timezone to use
* backup:increments: How many daily backup increments before a new full backup is made (default: 28)
* backup:retain: How long backups are retained, in weeks (default: '8)
* backup:openssl_key: aes-128-cbc key to encrypt backup tarballs with before uploading (128-bit hex)
* backup:openssl_iv: see above, but iv
* backup:bucket: what bucket to use (example: gs://my-mail-backup)
* boto:gs_oauth2_refresh_token: the "gs_oauth2_refresh_token" setting from boto.cfg to access google cloud storage
* boto:default_project_id: the "default_project_id" setting from boto.cfg to specify what GCS project to use

Services
--------
When running, the following services are exposed to the network on both IPv4 and IPv6:

* 25, 587: SMTP (tls required for authentication)
* 143, 993: IMAP (tls required)
* 4190: ManageSieve (tls required)
* 22: SSH (if not disabled)

Data
----
This image requires a delegated dataset. It will be mounted at /srv/mail and will store user
mailboxes. Also on this dataset is the user information:

* /srv/mail/passwd/&lt;domain&gt;: users per domain, formatted as user:passwd where passwd can be had using 'doveadm pw'
* /srv/mail/aliases/&lt;domain&gt;: aliases per domain, formatted as user:destination

TLS certificates from Let's Encrypt are used. They are stored on the delegated dataset in /srv/mail/ssl/dehydrated, 
along with the configuration for Dehydrated which is used to request them. To request certificates, add them to 
`domains.txt` in the above mentioned directory. By default, `dns-01` verification is used. 

Exim keeps its spool in /srv/mail/exim/spool so it is preserved upon reprovision. Also there are some configuration
lists in /srv/mail/exim/conf:

* global_aliases: aliases that exist in *all* handled domains. Suggested use is for a 'postmaster' alias.
* rewrite_domains: domains to rewrite to another domain, as domain: newdomain
* relay_from_hosts: hosts to relay for without authentication
* relay_to_domains: domains to be a secondary mx for, or otherwise relay to without authentication
* senderverify_exceptions: e-mail addresses to accept (on 'MAIL FROM:') without doing a verification callout
* dkim_required: domains (wildcard-matched) for which a valid DKIM signature is required to accept e-mail

Dovecot allows local configuration in /srv/mail/dovecot/conf/local.conf. This can be used for example to add an
imapc config to migrate mail from another server. 

A script is run nightly to create incremental tar-based backups and upload them to Google Cloud Storage. This 
should be adaptable to S3-based storage with minimal effort if necessary. It encrypts the tar files using 
openssl aes-128-cbc before uploading them, and saves the most recent tar in /srv/mail/backups for immediate use. 
If any of the required metadata keys (key, iv, bucket) are not set, the script will not run. 

Example JSON
------------
    {
      "brand": "joyent",
      "image_uuid": "",
      "alias": "poopmail",
      "hostname": "poopmail",
      "dns_domain": "poop.nl",
      "max_physical_memory": 1536,
      "cpu_shares": 100,
      "quota": 100,
      "delegate_dataset": "true",
      "nics": [
        {
          "nic_tag": "admin",
          "ips": ["1.2.3.4/24", "2001::1/64"],
          "gateways": ["1.2.3.1"],
          "primary": "true"
        }
      ],
      "resolvers": [
        "8.8.8.8",
        "8.8.4.4"
      ],
      "customer_metadata": {
        "system:ssh_disabled": "true",
        "system:timezone": "Europe/Amsterdam",
        "dovecot:qualify_domain": "cyberhq.nl",
        "dovecot:primary_hostname": "mail.poop.nl"
      }
    }


