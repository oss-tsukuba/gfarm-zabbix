#! /bin/sh
#
# Install the 'gfarm_zabbix' package for Zabbix agent.
#

. ./install.conf

# install(1) command.
INSTALL=install

# Directory where external scripts for Zabbix reside.
ZABBIX_EXTSCRIPTDIR=$ZABBIX_CONFDIR/externalscripts

# Directory where configuration files for Zabbix agentd reside.
ZABBIX_AGENTD_CONFSUBDIR=$ZABBIX_CONFDIR/zabbix_agentd.d

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
        -e "s|@ZABBIX_CONFDIR@|$ZABBIX_CONFDIR|g" \
        -e "s|@ZABBIX_EXTSCRIPTDIR@|$ZABBIX_EXTSCRIPTDIR|g" \
        -e "s|@ZABBIX_SYSLOG_FACILITY@|$ZABBIX_SYSLOG_FACILITY|g" \
        "$1.in" > "$1"
}

#
# Is $ZABBIX_PREFIX setting correct?
#
if [ ! -x "${ZABBIX_PREFIX}/sbin/zabbix_agent" -a \
     ! -x "${ZABBIX_PREFIX}/sbin/zabbix_agentd" ]; then
  echo >&2 "ERROR: ${ZABBIX_PREFIX}/sbin/zabbix_agent does not exist"
  echo >&2 "ERROR: check ZABBIX_PREFIX setting in install.conf"
  exit 1
fi

#
# Get parameters for accessing PostgreSQL.
#
PGHOST="`get_gfmd_conf_value postgresql_server_host`"
PGPORT="`get_gfmd_conf_value postgresql_server_port`"
PGDATABASE="`get_gfmd_conf_value postgresql_dbname`"
PGUSER="`get_gfmd_conf_value postgresql_user`"
PGPASSWORD="`get_gfmd_conf_value postgresql_password`"

#
# Install files in 'scripts/zabbix_agentd.d/' to
# $ZABBIX_AGENTD_CONFSUBDIR.
#
for I in \
    userparameter_gfarm.conf; do
    SRCFILE=scripts/zabbix_agentd.d/$I
    DSTFILE=$ZABBIX_AGENTD_CONFSUBDIR/$I
    create_file $SRCFILE
    $INSTALL -c -m 0755 -o root -g root $SRCFILE $DSTFILE \
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

SRCFILE=scripts/externalscripts/gfarm_conf.inc
DSTFILE=$ZABBIX_EXTSCRIPTDIR/gfarm_conf.inc
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

#
# Delete or notify obsolete files.
# 
OBSOLETE_FILES=
for I in \
    zbx_chk_dead_gfarm_pgsql.sh \
    zbx_chk_dead_gfmd.sh \
    zbx_chk_dead_gfsd.sh \
    zbx_chk_gfhost_cli.sh \
    zbx_chk_gfhost_gfsd.sh \
    zbx_chk_gfmdhost_cli.sh \
    zbx_chk_gfmdlist_cli.sh \
    zbx_chk_gfmdtype_gfmd.sh \
    zbx_chk_gfsched_gfmd.sh \
    zbx_chk_gfsched_gfsd.sh \
    zbx_chk_listenport_gfmd.sh \
    zbx_chk_listenport_gfsd.sh \
    zbx_chk_mastername_cli.sh \
    zbx_chk_pgsql.sh \
    zbx_failover.pl \
    zbx_gfarm_utils.inc; do
    [ -f $ZABBIX_EXTSCRIPTDIR/$I ] && rm -f $ZABBIX_EXTSCRIPTDIR/$I
done

for I in \
    $ZABBIX_EXTSCRIPTDIR/zbx_chk_gfarm.conf \
    $ZABBIX_AGENTD_CONFSUBDIR/userparameter_postgresql.conf \
    $ZABBIX_AGENTD_CONFSUBDIR/userparameter_redundant_gfarm.conf; do
    if [ -f $I ]; then
        echo "The following file is not used any longer:"
        echo "    $I"
        echo
    fi
done

#
# Change mode of $GFARM_SYSLOG_FILE
#
chmod 0644 $GFARM_SYSLOG_FILE \
    && echo "Set mode (= 0644) of the file: $GFARM_SYSLOG_FILE"
