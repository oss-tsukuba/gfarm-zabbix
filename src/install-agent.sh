#! /bin/sh
#
# Install the 'gfarm_zabbix' package for Zabbix agent.
#

. ./install.conf

# install(1) command.
INSTALL=install

#
# The following directories must be explicitly configured.
# Empty values may cause configuration files or scripts to be
# installed directly under '/', which is almost certainly
# unintended.
#
for I in \
    ZABBIX_EXTSCRIPTDIR \
    ZABBIX_GFARM_CONFDIR \
    ZABBIX_HOMEDIR
do
    eval VALUE=\$$I
    if [ -z "$VALUE" ]; then
        echo >&2 "ERROR: $I must not be empty"
        exit 1
    fi
done

#
# Determine ZABBIX_AGENT_BIN and ZABBIX_AGENT_CONFDIR.
# If either of them is explicitly specified, derive the
# other value when possible. Otherwise, auto-detect both.
#
if [ -n "$ZABBIX_AGENT_BIN" ]; then
    if [ ! -x "$ZABBIX_AGENT_BIN" ]; then
        echo >&2 \
            "ERROR: ZABBIX_AGENT_BIN ($ZABBIX_AGENT_BIN)" \
            "is not executable or does not exist"
        exit 1
    fi

    case "$(basename "$ZABBIX_AGENT_BIN")" in
    zabbix_agent2)
        : ${ZABBIX_AGENT_CONFDIR:=/etc/zabbix/zabbix_agent2.d}
        ;;
    zabbix_agentd)
        : ${ZABBIX_AGENT_CONFDIR:=/etc/zabbix/zabbix_agentd.d}
        ;;
    *)
        if [ -z "$ZABBIX_AGENT_CONFDIR" ]; then
            echo >&2 \
                "ERROR: Cannot determine the default value of" \
                " ZABBIX_AGENT_CONFDIR from" \
                " ZABBIX_AGENT_BIN ($ZABBIX_AGENT_BIN)"
            echo >&2 \
                "ERROR: Please set ZABBIX_AGENT_CONFDIR explicitly"
            exit 1
        fi
        ;;
    esac
elif [ -n "$ZABBIX_AGENT_CONFDIR" ]; then
    case "$(basename "$ZABBIX_AGENT_CONFDIR")" in
    zabbix_agent2.d)
        : ${ZABBIX_AGENT_BIN:="${ZABBIX_PREFIX}/sbin/zabbix_agent2"}
        ;;
    zabbix_agentd.d)
        : ${ZABBIX_AGENT_BIN:="${ZABBIX_PREFIX}/sbin/zabbix_agentd"}
        ;;
    *)
        if [ -z "$ZABBIX_AGENT_BIN" ]; then
            echo >&2 \
                "ERROR: Cannot determine the default value of" \
                " ZABBIX_AGENT_BIN from" \
                " ZABBIX_AGENT_CONFDIR ($ZABBIX_AGENT_CONFDIR)"
            echo >&2 \
                "ERROR: Please set ZABBIX_AGENT_BIN explicitly"
            exit 1
        fi
        ;;
    esac
    if [ ! -x "$ZABBIX_AGENT_BIN" ]; then
        echo >&2 \
            "ERROR: ZABBIX_AGENT_BIN ($ZABBIX_AGENT_BIN)" \
            " is not executable or does not exist"
        exit 1
    fi
else
    # Auto-detect the Zabbix agent executable and
    # its user configuration directory if not specified.
    if [ -x "${ZABBIX_PREFIX}/sbin/zabbix_agent2" ]; then
        : ${ZABBIX_AGENT_CONFDIR:=/etc/zabbix/zabbix_agent2.d}
        : ${ZABBIX_AGENT_BIN:="${ZABBIX_PREFIX}/sbin/zabbix_agent2"}
    elif [ -x "${ZABBIX_PREFIX}/sbin/zabbix_agentd" ]; then
        : ${ZABBIX_AGENT_CONFDIR:=/etc/zabbix/zabbix_agentd.d}
        : ${ZABBIX_AGENT_BIN:="${ZABBIX_PREFIX}/sbin/zabbix_agentd"}
    elif [ -x "${ZABBIX_PREFIX}/sbin/zabbix_agent" ]; then
        : ${ZABBIX_AGENT_CONFDIR:=/etc/zabbix/zabbix_agentd.d}
        : ${ZABBIX_AGENT_BIN:="${ZABBIX_PREFIX}/sbin/zabbix_agent"}
    else
        echo >&2 \
            "ERROR: No Zabbix agent executable found" \
            " under ${ZABBIX_PREFIX}/sbin"
        echo >&2 "ERROR: check ZABBIX_PREFIX setting in install.conf"
        exit 1
    fi
fi

# User name of Zabbix.
ZABBIX_USER=zabbix

# Group name of Zabbix.
ZABBIX_GROUP=zabbix

#
# Get value of a particular parameter defined in 'gfmd.conf'.
#
get_gfmd_conf_value()
{
    [ -f $GFMD_CONF_FILE ] && \
        awk '$1 == "'"$1"'" { print $2 }' $GFMD_CONF_FILE
}

#
# Create "$1" file from "$1.in".
#
create_file()
{
    [ -f "$1".in ] || return 0
    [ -f "$1" ] && rm -f "$1"
    sed \
        -e "s|@GFARM_BINDIR@|$GFARM_BINDIR|g" \
        -e "s|@GFMD_CONFIG_PREFIX@|$GFMD_CONFIG_PREFIX|g" \
        -e "s|@POSTGRES_PID_FILE@|$POSTGRES_PID_FILE|g" \
        -e "s|@POSTGRES_USER@|$POSTGRES_USER|g" \
        -e "s|@PGHOST@|$PGHOST|g" \
        -e "s|@PGPORT@|$PGPORT|g" \
        -e "s|@PGDATABASE@|$PGDATABASE|g" \
        -e "s|@PGUSER@|$PGUSER|g" \
        -e "s|@PGPASSWORD@|$PGPASSWORD|g" \
        -e "s|@ZABBIX_PREFIX@|$ZABBIX_PREFIX|g" \
        -e "s|@ZABBIX_AGENT_BIN@|$ZABBIX_AGENT_BIN|g" \
        -e "s|@ZABBIX_HOMEDIR@|$ZABBIX_HOMEDIR|g" \
        -e "s|@ZABBIX_EXTSCRIPTDIR@|$ZABBIX_EXTSCRIPTDIR|g" \
        -e "s|@ZABBIX_GFARM_CONFDIR@|$ZABBIX_GFARM_CONFDIR|g" \
        -e "s|@ZABBIX_SYSLOG_FACILITY@|$ZABBIX_SYSLOG_FACILITY|g" \
        "$1.in" > "$1"
}

#
# Get parameters for accessing PostgreSQL.
#
PGHOST="`get_gfmd_conf_value postgresql_server_host`"
PGPORT="`get_gfmd_conf_value postgresql_server_port`"
PGDATABASE="`get_gfmd_conf_value postgresql_dbname`"
PGUSER="`get_gfmd_conf_value postgresql_user`"
PGPASSWORD="`get_gfmd_conf_value postgresql_password`"

#
# Install files in 'scripts/zabbix_agent.d/' to
# $ZABBIX_AGENT_CONFDIR.
#
for I in \
    userparameter_gfarm.conf; do
    SRCFILE=scripts/zabbix_agent.d/$I
    DSTFILE=$ZABBIX_AGENT_CONFDIR/$I
    create_file $SRCFILE
    $INSTALL -c -m 0644 -o root -g root $SRCFILE $DSTFILE \
        || { echo "Failed to install the file: $DSTFILE"; exit 1; }
    echo "Install the file: $DSTFILE"
done

#
# Make a directory '$ZABBIX_EXTSCRIPTDIR'.
#
DIR=$ZABBIX_EXTSCRIPTDIR
if [ ! -d $DIR ]; then
    $INSTALL -d -m 0755 -o root -g root $DIR \
        || { echo "Failed to create the directory: $DIR"; exit 1; }
    echo "Create the directory: $DIR"
fi

#
# Install files in 'scripts/externalscripts/' to
# $ZABBIX_EXTSCRIPTDIR.
#
for I in \
    gfarm_generic_client_gfhost.sh \
    gfarm_generic_client_gfmdhost.sh \
    gfarm_gfmd_failover.pl \
    gfarm_gfmd_failover_agent.pl \
    gfarm_gfmd_failover_common.pl \
    gfarm_gfmd_gfhost.sh \
    gfarm_gfmd_postgresql.sh \
    gfarm_gfmd_postgresql_alive.sh \
    gfarm_gfsd_gfhost.sh \
    gfarm_gfsd_gfsched.sh \
    gfarm_represent_client_gfhost.sh \
    gfarm_represent_client_gfmdhost.sh \
    gfarm_represent_client_gfmdhost2.sh \
    gfarm_utils.inc; do
    SRCFILE=scripts/externalscripts/$I
    DSTFILE=$ZABBIX_EXTSCRIPTDIR/$I
    create_file $SRCFILE
    $INSTALL -c -m 0755 -o $ZABBIX_USER -g $ZABBIX_GROUP $SRCFILE $DSTFILE \
        || { echo "Failed to install the file: $DSTFILE"; exit 1; }
    echo "Install the file: $DSTFILE"
done

DIR=$ZABBIX_GFARM_CONFDIR
if [ ! -d $DIR ]; then
    $INSTALL -d -m 0755 -o root -g root $DIR \
        || { echo "Failed to create the directory: $DIR"; exit 1; }
fi
SRCFILE=scripts/externalscripts/gfarm_conf.inc
DSTFILE=$ZABBIX_GFARM_CONFDIR/gfarm_conf.inc
create_file $SRCFILE
$INSTALL -c -m 0700 -o $ZABBIX_USER -g $ZABBIX_GROUP $SRCFILE $DSTFILE \
    || { echo "Failed to install the file: $DSTFILE"; exit 1; }
echo "Install the file: $DSTFILE"

#
# sanity check about gfmd.failover.{,agent.}conf
#
if [ -f "$GFMD_CONF_FILE" ] &&
   [ X"`get_gfmd_conf_value metadb_replication`" = X"enable" ]
then
    for I in \
	"`dirname $GFMD_CONF_FILE`/gfmd.failover.conf" \
	"`dirname $GFMD_CONF_FILE`/gfmd.failover.agent.conf"
    do
	if [ ! -f "$I" ]; then
	    echo >&2 "WARNING: missing $I," \
		"try config-gfarm-update --update," \
		"otherwise failover_type=availabilty setting won't work"
	fi
    done
    I="`dirname $GFMD_CONF_FILE`/gfmd.failover.conf"
    if [ -f "$I" ]; then
	if egrep '^[	 ]*include[ 	]+([^ 	#]*/)?gfmd\.failover\.agent\.conf([ 	#]|$)' "$I" >/dev/null
	then
	    : # OK
	else
	    echo >&2 "WARNING: missing 'include gfmd.failover.agent.conf'" \
		"in $I, please add it," \
		"otherwise failover_type=availabilty setting won't work"
	fi
    fi
fi

if [ "$(basename "$ZABBIX_AGENT_BIN")" = "zabbix_agent2" ]; then
    OLD_AGENTD_CONFDIR=$(dirname "$ZABBIX_AGENT_CONFDIR")/zabbix_agentd.d

    for I in \
        $OLD_AGENTD_CONFDIR/userparameter_gfarm.conf ; do
        if [ -f "$I" ]; then
            echo "The following file is not used any longer:"
            echo "    $I"
            echo
        fi
    done
fi

#
# Change mode of $GFARM_SYSLOG_FILE
#
chmod 0644 $GFARM_SYSLOG_FILE \
    && echo "Set mode (= 0644) of the file: $GFARM_SYSLOG_FILE"
