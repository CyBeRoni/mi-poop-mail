#!/usr/bin/bash

if [ -n "$EX4DEBUG" ]; then
  echo "now debugging $0 $@"
  set -x
fi


# set this to some other value if you don't want the panic log to be
# watched by this script, for example when you're using your own log
# checking mechanisms or don't care.

E4BCD_DAILY_REPORT_TO=""
E4BCD_DAILY_REPORT_OPTIONS=""
E4BCD_WATCH_PANICLOG="once"
# Number of lines of paniclog quoted in warning email.
E4BCD_PANICLOG_LINES="10"
E4BCD_PANICLOG_NOISE=""

# Only do anything if exim4 is actually installed
if [ ! -x /opt/local/sbin/exim ]; then
  exit 0
fi

SPOOLDIR="$(exim -bP spool_directory | sed 's/.*=[[:space:]]\(.*\)/\1/')"

# The log processing code used in this cron script is not very
# sophisticated. It relies on this cron job being executed earlier than
# the log rotation job, and will have false results if the log is not
# rotated exactly once daily in the daily cron processing. Even in the
# default configuration, it will ignore log entries made between this
# cron job and the log rotation job.

# Patches for more sophisticated processing are appreciated via the
# Debian BTS.

E4BCD_MAINLOG_NOISE="^[[:digit:][:space:]:-]\{20\}\(\(Start\|End\) queue run: pid=[[:digit:]]\+\|exim [[:digit:]\.]\+ daemon started: pid=[[:digit:]]\+, .*\)$"

if [ -n "$E4BCD_DAILY_REPORT_TO" ]; then
  if [ -x "$(command -v eximstats)" ] && [ -x "$(command -v mailx)" ]; then
    if [ "$(< /var/log/exim/main grep -v "$E4BCD_MAINLOG_NOISE" | wc -l)" -gt "0" ]; then
      < /var/log/exim/main grep -v "$E4BCD_MAINLOG_NOISE" \
                | eximstats $E4BCD_DAILY_REPORT_OPTIONS \
                | mailx -s"$(hostname) Daily e-mail activity report" $E4BCD_DAILY_REPORT_TO 
    else
      echo "no mail activity in this interval" \
                | mailx -s"$(hostname) Daily e-mail activity report" $E4BCD_DAILY_REPORT_TO
    fi
  else
    echo "The exim cron job is configured to send a daily report, but eximstats"
    echo "and/or mail cannot be found. Please check and make sure that these two"
    echo "binaries are available"
  fi
fi

log_this() {
  TEXT="$@"
  if ! logger -t exim -p mail.alert $TEXT; then
    RET="$?"
    echo >&2 "ALERT: could not syslog $TEXT, logger return value $RET"
  fi
}

if [ "$E4BCD_WATCH_PANICLOG" != "no" ]; then
  if [ -s "/var/log/exim/panic" ]; then
    if [ -z "$E4BCD_PANICLOG_NOISE" ] || grep -vq "$E4BCD_PANICLOG_NOISE" /var/log/exim/panic; then
      log_this "ALERT: exim paniclog /var/log/exim/panic has non-zero size, mail system possibly broken"
      if ! printf "Subject: exim paniclog on %s has non-zero size\nTo: root\n\nexim paniclog /var/log/exim/panic on %s has non-zero size, mail system might be broken. The last ${E4BCD_PANICLOG_LINES} lines are quoted below.\n\n%s\n" \
      "$(hostname)" "$(hostname)" \
      "$(tail -n "${E4BCD_PANICLOG_LINES}" /var/log/exim/panic)" \
      | exim root; then
        log_this "PANIC: sending out e-mail warning has failed, exim has non-zero return code"
      fi
      if [ "$E4BCD_WATCH_PANICLOG" = "once" ]; then
        logadm -p now -C 10 -o mail -g mail -m 640 /var/log/exim/panic
      fi
    fi
  fi
fi

# run tidydb as mail:mail
if [ -x /opt/local/sbin/exim_tidydb ]; then
  cd $SPOOLDIR/db || exit 1
  find $SPOOLDIR/db -maxdepth 1 -name '*.lockfile' -or -name 'log.*' \
    -or -type f -print0 | \
    sudo -u mail xargs -0 -n 1 /opt/local/sbin/exim_tidydb $SPOOLDIR > /dev/null
fi
