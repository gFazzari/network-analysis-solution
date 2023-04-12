#!/bin/bash

# Define usefull variables
ZEEK_CORES=${ZEEK_CORES:=4}
PROCS=$(seq -s ',' 0 $((${ZEEK_CORES} - 1 )))
CLUSTER_ID=49

# Determine interfaces
if [ -z ${NETWORK_INTERFACE2+x} ]; then
  NETWORK_INTERFACES=($NETWORK_INTERFACE1)
else
  NETWORK_INTERFACES=($NETWORK_INTERFACE1 $NETWORK_INTERFACE2)
fi

# Disable offloading network feature
for offload in rx tx sg tso ufo gso gro lro; do
  for int in ${NETWORK_INTERFACES[@]}; do
    ethtool -K $int $offload off
  done
done

# Zeek config for each iface
for iface in ${NETWORK_INTERFACES[@]}; do
  IFACES_CONF=$IFACES_CONF$(cat << EOF

[worker-$iface]
type=worker
host=localhost
interface=af_packet::$iface
lb_method=custom
lb_procs=$ZEEK_CORES
pin_cpus=$PROCS
af_packet_fanout_id=$CLUSTER_ID

EOF
  )
  CLUSTER_ID=$(( CLUSTER_ID - 1 ))
done

# Write zeek network config
cat << EOF > /usr/local/zeek/etc/node.cfg
[manager]
type=manager
host=localhost
 
[proxy-1]
type=proxy
host=localhost

$IFACES_CONF
EOF

# Write zeek config
cat << EOF > /usr/local/zeek/etc/zeekctl.cfg
## Global ZeekControl configuration file.

###############################################
# Mail Options

# Recipient address for all emails sent out by Zeek and ZeekControl.
MailTo = fazz.gab@live.it

# Mail connection summary reports each log rotation interval.  A value of 1
# means mail connection summaries, and a value of 0 means do not mail
# connection summaries.  This option has no effect if the trace-summary
# script is not available.
MailConnectionSummary = 0

# Lower threshold (in percentage of disk space) for space available on the
# disk that holds SpoolDir. If less space is available, "zeekctl cron" starts
# sending out warning emails.  A value of 0 disables this feature.
MinDiskSpace = 5

# Send mail when "zeekctl cron" notices the availability of a host in the
# cluster to have changed.  A value of 1 means send mail when a host status
# changes, and a value of 0 means do not send mail.
MailHostUpDown = 1

###############################################
# Logging Options

# Rotation interval in seconds for log files on manager (or standalone) node.
# A value of 0 disables log rotation.
LogRotationInterval = 3600

# Expiration interval for archived log files in LogDir.  Files older than this
# will be deleted by "zeekctl cron".  The interval is an integer followed by
# one of these time units:  day, hr, min.  A value of 0 means that logs
# never expire.
LogExpireInterval = 1hr

# Enable ZeekControl to write statistics to the stats.log file.  A value of 1
# means write to stats.log, and a value of 0 means do not write to stats.log.
StatsLogEnable = 1

# Number of days that entries in the stats.log file are kept.  Entries older
# than this many days will be removed by "zeekctl cron".  A value of 0 means
# that entries never expire.
StatsLogExpireInterval = 1

###############################################
# Other Options

# Show all output of the zeekctl status command.  If set to 1, then all output
# is shown.  If set to 0, then zeekctl status will not collect or show the peer
# information (and the command will run faster).
StatusCmdShowAll = 0

# Number of days that crash directories are kept.  Crash directories older
# than this many days will be removed by "zeekctl cron".  A value of 0 means
# that crash directories never expire.
CrashExpireInterval = 0

# Site-specific policy script to load. Zeek will look for this in
# $PREFIX/share/zeek/site. A default local.zeek comes preinstalled
# and can be customized as desired.
SitePolicyScripts = local.zeek

# Location of the log directory where log files will be archived each rotation
# interval.
LogDir = /usr/local/zeek/logs/

# Location of the spool directory where files and data that are currently being
# written are stored.
SpoolDir = /usr/local/zeek/spool

# Location of the directory in which the databases for Broker datastore backed
# Zeek tables are stored.
BrokerDBDir = /usr/local/zeek/spool/brokerstore

# Location of other configuration files that can be used to customize
# ZeekControl operation (e.g. local networks, nodes).
CfgDir = /usr/local/zeek/etc
EOF

# Print ifaces
for iface in ${NETWORK_INTERFACES[@]}; do
  echo "Zeek configured for interface $iface"
done

# Go
zeekctl deploy

if [ $? -eq 1 ]; then
    exit -1
fi

echo "Zeek has started..."
trap 'stop' SIGINT SIGTERM SIGHUP SIGQUIT SIGABRT SIGKILL
trap - ERR
while :; do sleep 1s; done
