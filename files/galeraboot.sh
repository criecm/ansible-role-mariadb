#!/bin/sh -e
#
MAXTIME=1200
BEGIN=$(date +%s)

mydir=/var/tmp/galeraboot.$$
[ -e $mydir ] && rm -rf $mydir
mkdir -p $mydir

# les NODES doivent etre dans /root/.galera.nodes
. /root/.galera.nodes
[ -n "$NODES" ] || exit 1
if echo $NODES | grep -q "^$(hostname -s) "; then
  master=1
else
  master=0
fi

# usage ssh_galeraboot host script_command
ssh_galeraboot() {
  # wrapper for script command
  if [ -n "$SSH_AUTH_SOCK" -a -e "$SSH_AUTH_SOCK" ]; then
    # manual launch
    ssh $1 -oConnectTimeout=1 /root/galeraboot_ssh_callback.sh $2 || return 1
  else
    unset SSH_AUTH_SOCK
    ssh -i /root/.ssh/id_rsa_galeraboot -oConnectTimeout=3 $1 $2 || return 1
  fi
}

SLEEP=1
NODESDOWN=0
WORKINGNODES=0
NBNODES=$(echo $NODES | wc -w)
winner=""
while [ $(( NODESDOWN + WORKINGNODES )) -lt $NBNODES ]; do
  echo "$(( NODESDOWN + WORKINGNODES ))/$(( NBNODES ))"
  if [ $(( $(date +%s) - $BEGIN )) -gt $MAXTIME ]; then echo "trop long. (>$MAXTIME)"; exit 1; fi
  for node in $NODES; do
    [ -s $mydir/status.$node ] && continue
    ssh_galeraboot $node getstatus > $mydir/status.$node || continue
    if [ "$(cat $mydir/status.$node)" = "running" ]; then
      #echo "$node running ?";
      if clusterstatus=$(ssh_galeraboot $node getclusterstatus); then
        #echo "cluster status: $clusterstatus";
	if echo $clusterstatus | egrep -q '(Synced|Donnor)'; then
	  echo "$node is all OK ($clusterstatus)"
	  WORKINGNODES=$(( WORKINGNODES + 1 ))
	  winner="$node"
	else
	  echo "$node clusterstatus=$clusterstatus: shutdown mysql"
          ssh_galeraboot $node down
	  ssh_galeraboot $node getstatus > $mydir/status.$node
        fi
      else
        echo "$node clusterstatus=$clusterstatus: shutdown mysql"
        ssh_galeraboot $node down
	ssh_galeraboot $node getstatus > $mydir/status.$node
      fi
      continue;
    fi
    if [ "$(cat $mydir/status.$node)" = "down" ]; then
      echo "$node has mysqld down";
      NODESDOWN=$(( NODESDOWN + 1 ));
    fi
  done
  sleep $SLEEP
  #SLEEP=$(( SLEEP * 2 ))
done

if [ $(( NODESDOWN + WORKINGNODES )) -lt $NBNODES ]; then
  echo "All nodes are not \"up with mysqld down\" and no really working one: exit"
  exit 1
fi

[ $WORKINGNODES -eq $NBNODES ] && exit 0

if [ -z "$winner" -a $NODESDOWN -eq $NBNODES ]; then
  # no working node: launch recover and find most advanced one
  max=0
  uuid=""
  for node in $NODES; do
    # is any node safe to bootstrap ?
    if [ $(ssh_galeraboot $node getsafe) -eq 1 ]; then
      echo "$node is safe_to_bootstrap: winner"
      winner=$node
      break
    fi
    # all nodes need to have the same uuid
    if [ -z "$uuid" ]; then uuid=$(ssh_galeraboot $node getuuid); else
      hisuuid=$(ssh_galeraboot $node getuuid)
      if [ "$hisuuid" != "$uuid" ]; then
        echo "UUID check: $node has $hisuuid while we have $uuid"
        echo " not the same cluster ???"
        exit 1
      fi
    fi
    last=$(ssh_galeraboot $node getlast || echo -1)
    echo "$node has $last"
    if [ $last -gt $max ]; then
      max=$last
      winner=$node
    fi
  done
fi

if [ -n "$winner" ]; then
  echo "winner: $winner"
  if [ $WORKINGNODES -eq 0 ]; then
    if [ $(ssh_galeraboot $winner getsafe) -eq 0 ]; then
      echo "force safe_to_bootstrap=1 on $winner"
      ssh_galeraboot $winner setsafe
    fi
    echo "bootcluster $winner"
    ssh_galeraboot $winner bootcluster
  fi
  for node in $NODES; do
    [ "$node" = "$winner" ] && continue
    if [ "$(ssh_galeraboot $node getstatus)" = "down" ]; then
      echo "start mariadb on $node"
      ssh_galeraboot $node boot
    fi
  done
else
  echo "no winner here :'("
  exit 1
fi
