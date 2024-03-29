#!/bin/sh
#
# Script to make a proxy (ie HAProxy) capable of monitoring Galera Cluster nodes properly
#
# Based on the original script from Olaf van Zandwijk <olaf.vanzandwijk@nedap.com>, Raghavendra Prabhu <raghavendra.prabhu@percona.com>
#

if [ "$1" = "-h" -o "$1" = "--help" ];then
    echo "Usage: $0 <user> <pass> <available_when_donor=0|1> <log_file> <available_when_readonly=0|1> <defaults_extra_file>"
    exit
fi

httpReply() {
    HTTP_STATUS="${1}"
    RESPONSE_CONTENT="${2}"
    CONTENT_LENGTH=$(( $(echo $RESPONSE_CONTENT | wc -c) ))

    if [ "${HTTP_STATUS}" = "503" ]
    then
        printf "HTTP/1.1 503 Service Unavailable\r\n"
    elif [ "${HTTP_STATUS}" = "200" ]
    then
        printf "HTTP/1.1 200 OK\r\n"
    else
        printf "HTTP/1.1 ${HTTP_STATUS}\r\n"
    fi

    printf "Content-Type: text/plain\r\n"
    printf "Connection: close\r\n"
    printf "Content-Length: ${CONTENT_LENGTH}\r\n"
    printf "\r\n"
    printf "${RESPONSE_CONTENT}"
    sleep 0.1
}

# if the disabled file is present, return 503. This allows
# admins to manually remove a node from a cluster easily.
if [ -e "/var/tmp/clustercheck.disabled" ]; then
    # Shell return-code is 1
    httpReply "503" "Galera Cluster Node is manually disabled.\r\n"
    exit 1
fi

MYSQL_USERNAME="${1:-clustercheckuser}"
MYSQL_PASSWORD="${2:-clustercheckpassword!}"
AVAILABLE_WHEN_DONOR=${3:-0}
ERR_FILE="${4:-/dev/null}"
AVAILABLE_WHEN_READONLY=${5:-1}
DEFAULTS_EXTRA_FILE=${6:-/etc/my.cnf}

#Timeout exists for instances where mysqld may be hung
TIMEOUT=10

EXTRA_ARGS=""
if [ -n "$MYSQL_USERNAME" ]; then
    EXTRA_ARGS="$EXTRA_ARGS --user=${MYSQL_USERNAME}"
fi
if [ -n "$MYSQL_PASSWORD" ]; then
    EXTRA_ARGS="$EXTRA_ARGS --password=${MYSQL_PASSWORD}"
fi
if [ -r $DEFAULTS_EXTRA_FILE ];then
    MYSQL_CMDLINE="mysql --defaults-extra-file=$DEFAULTS_EXTRA_FILE -nNE --connect-timeout=$TIMEOUT \
                    ${EXTRA_ARGS}"
else
    MYSQL_CMDLINE="mysql -nNE --connect-timeout=$TIMEOUT ${EXTRA_ARGS}"
fi
#
# Perform the query to check the wsrep_local_state
#
WSREP_STATUS=$($MYSQL_CMDLINE -e "SHOW STATUS LIKE 'wsrep_local_state';" \
    2>${ERR_FILE} | tail -1 2>>${ERR_FILE})

if [ "${WSREP_STATUS}" = "4" ] || [ "${WSREP_STATUS}" = "2" -a ${AVAILABLE_WHEN_DONOR} = 1 ]
then
    # Check only when set to 0 to avoid latency in response.
    if [ $AVAILABLE_WHEN_READONLY -eq 0 ];then
        READ_ONLY=$($MYSQL_CMDLINE -e "SHOW GLOBAL VARIABLES LIKE 'read_only';" \
                    2>${ERR_FILE} | tail -1 2>>${ERR_FILE})

        if [ "${READ_ONLY}" = "ON" ];then
            # Galera Cluster node local state is 'Synced', but it is in
            # read-only mode. The variable AVAILABLE_WHEN_READONLY is set to 0.
            # => return HTTP 503
            # Shell return-code is 1
            httpReply "503" "Galera Cluster Node is read-only.\r\n"
            exit 1
        fi
    fi
    # Galera Cluster node local state is 'Synced' => return HTTP 200
    # Shell return-code is 0
    httpReply "200" "Galera Cluster Node is synced.\r\n"
    exit 0
else
    # Galera Cluster node local state is not 'Synced' => return HTTP 503
    # Shell return-code is 1
    httpReply "503" "Galera Cluster Node is not synced.\r\n"
    exit 1
fi
