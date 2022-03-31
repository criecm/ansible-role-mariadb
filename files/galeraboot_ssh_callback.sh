#!/bin/sh
if [ $# -ne 0 ]; then
  SSH_ORIGINAL_COMMAND=$@
fi
n=$(date +%s)
pname=mysqld
# 10.5+
if [ -x /usr/local/libexec/mariadbd -a ! -L /usr/local/libexec/mariadbd ]; then
  pname=mariadbd
fi

if [ "$SSH_ORIGINAL_COMMAND" = "ping" ]; then
  echo "pong"
  exit 0
fi
DATADIR=$(sysrc -nq mysql_dbdir || echo /var/db/mysql)
if ! [ -d "$DATADIR" ]; then
  echo "no DATADIR $DATADIR: exit" >&2
  exit 1
fi
STATUS=$(pgrep -qx $pname && echo running || echo down)
if ! [ -s $DATADIR/grastate.dat ]; then
  echo "no $DATADIR/grastate.dat: exit" >&2
  exit 1
fi
UUID=$(grep ^uuid: $DATADIR/grastate.dat | awk '{print $2}')
if ! [ -n "$UUID" ]; then
  echo "no uuid in $DATADIR/grastate.dat: exit" >&2
  exit 1
fi
SAFE=$(grep ^safe_to_bootstrap $DATADIR/grastate.dat | awk '{print $2}')
if ! [ -n "$SAFE" -a $SAFE -eq 0 -o $SAFE -eq 1 ]; then
  echo "no safe_to_bootstrap in $DATADIR/grastate.dat ($SAFE): exit"
  exit 1
fi

case "$SSH_ORIGINAL_COMMAND" in
  getstatus)
    echo $STATUS
    break
  ;;
  getclusterstatus)
    if [ "$STATUS" = "running" ]; then
      state=$(mysql -e "show status LIKE 'wsrep_local_state_comment'" -BsNE|tail -1)
      case "$state" in
        Joined|Synced|Donnor)
          echo "$state"
          exit 0
          break
        ;;
        Joining|Waiting*)
          echo "$state"
          exit 0
          break
        ;;
        Initialized)
          echo "$state"
          exit 1
          break
        ;;
        *)
          echo "none"
          exit 1
          break
        ;;
      esac
    else
      echo "down";
    fi
  ;;
  getuuid)
    echo $UUID
    break
  ;;
  getlast)
    if [ "$STATUS" = "down" ]; then
      if [ ! -s /tmp/lastme ]; then
        oargs=$(sysrc -nq mysql_args)
        if ! echo -- "$oargs" | grep -q wsrep_recover; then
          sysrc mysql_args="$oargs --wsrep_recover" > /dev/null
          service mysql-server onestart > /dev/null
          sysrc mysql_args="$oargs" > /dev/null
        fi
        last=$(grep "WSREP: Recovered position.*$UUID:" /var/log/mysql/mariadb.log | tail -1 | sed 's/^.*://g')
        if [ -n "$last" ]; then
          echo $last > /tmp/lastme
        else
          echo "0" > /tmp/lastme
        fi
      fi
    fi
    cat /tmp/lastme
    break
  ;;
  getsafe)
    echo $SAFE
    break
  ;;
  setsafe)
    if [ "$STATUS" = "down" -a "$SAFE" -eq 0 ]; then
      sed -i ".$DATE" "s/^\(safe_to_bootstrap: *\) 0/\1 1/" $DATADIR/grastate.dat
    else
      return 1
    fi
    break
  ;;
  bootcluster)
    if [ "$STATUS" = "down" ]; then
      if [ $SAFE -eq 1 ]; then
        oldarg=$(/usr/sbin/sysrc -n mysql_args | sed s/--wsrep-new-cluster//)
        /usr/sbin/sysrc mysql_args="$oldarg --wsrep-new-cluster"
        /usr/sbin/service mysql-server onestart
        /usr/sbin/sysrc mysql_args="$oldarg"
      fi
    fi
    rm -f /tmp/lastme
    break
  ;;
  boot)
    if [ "$STATUS" = "down" ]; then
      /usr/sbin/service mysql-server onestart
    fi
    rm -f /tmp/lastme
    break
  ;;
  down)
    if [ "$STATUS" = "running" ]; then
      service mysql-server onestop
      sleep 3
      if pgrep -flu mysql; then
        pkill -u mysql
        sleep 3
        if pgrep -flu mysql; then
          pkill -9 -u mysql
          sleep 3
        fi
      fi
    fi
    rm -f /tmp/lastme
    break
  ;;
  *)
    echo "just read it"
    return 1
    break
  ;;
esac
