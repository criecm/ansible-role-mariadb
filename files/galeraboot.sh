#!/bin/sh -e
MAX=300
n=$(date +%s)
pname=mysqld
# 10.5+
if [ -x /usr/local/libexec/mariadbd ]; then
  pname=mariadbd
fi
DATADIR=$(sysrc mysql_dbdir || echo /var/db/mysql)
if ! pgrep -qx $pname; then
  if grep -q '^safe_to_bootstrap: 1$' $DATADIR/grastate.dat; then
    oldarg=$(/usr/sbin/sysrc -n mysql_args | sed s/--wsrep-new-cluster//)
    /usr/sbin/sysrc mysql_args="$oldarg --wsrep-new-cluster"
    /usr/sbin/service mysql-server onestart
    /usr/sbin/sysrc mysql_args="$oldarg"
  else
    while ! pgrep -qx $pname && [ $(( $(date +%s) - n )) -lt $MAX ]; do
      sleep $(( 10 * $(hostname -s | sed s/[^0-9]//) ))
      /usr/sbin/service mysql-server onestart
      sleep 30
    done
  fi
fi
