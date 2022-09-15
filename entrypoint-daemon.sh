#!/bin/bash
# 
# Sven Siebler <sven.siebler@urz.uni-heidelberg.de> 2022

# determine IB interface (mlx4_0, etc) via external device list, because container can not access IBtools or IB interface directly
if [[ ! -f /config/ibdevices.lst ]];then
	echo "no information about IB devices available!"
	exit 1
fi

IBDEV=`grep $DAEMONHOST /config/ibdevices.lst | head -1`
echo "detected IB device from Host: $IBDEV"

ibdev=`echo $IBDEV | egrep 'ib[0-9]' | awk '{print $2}'`
ib_port=`echo $IBDEV | egrep 'ib[0-9]' | awk '{print $4}'`

# create daemon config
cat <<EOF > /tmp/config.json
{
  "api": {
    "entry_point": "${API_SERVER}",
    "token": "${API_TOKEN}",
    "fabric_id": "${FABRIC_ID}"
  },
  "ca_name": "${ibdev}",
  "ca_port": ${ib_port},
  "topology_update_interval_sec": 180,
  "port_stats_interval_sec": 5,
  "node_name_map": "/config/ib_topology.map"
}
EOF
cat /tmp/config.json

/usr/sbin/infiniband_radar_daemon /tmp/config.json
