#!/bin/bash

# Only allocate a broker id and configure the system the first time this container starts.
# A Kubernetes volume mount will preserve the config if the container dies and is restarted
# in the same node.

if [[ -n "${COORDINATION_PATH}" ]]; then
	while [[ ! -e "${COORDINATION_PATH}" ]]; do sleep 1; done
fi

if [ ! -f /kafka/config/server.properties ]; then
	# Create a ZK connection string for the servers and the root.
	ZOOKEEPER_CONNECT=()
	IFS=\, read -a servers <<< "${ZOOKEEPER_SERVERS:=zookeeper:2181}"
	for server in "${servers[@]}"; do 
		ZOOKEEPER_CONNECT+=("$server${ZOOKEEPER_ROOT:=/kafka}")
	done
	ZOOKEEPER_CONNECT=$(IFS=, ; echo "${ZOOKEEPER_CONNECT[*]}")

	echo "Using ZK at ${ZOOKEEPER_CONNECT}"

	# Create the ZK root if it doesn't already exist.
	echo create "$ZOOKEEPER_ROOT" 0 | zookeeper-shell $ZOOKEEPER_SERVERS &> /dev/null

	if [ -z $BROKER_ID ]; then
		# Create node to use for id allocation.
		# TODO: echo create $ZOOKEEPER_ROOT/id_alloc 0 | /usr/bin/zookeeper-shell $ZOOKEEPER_CONNECT &> /dev/null
		echo create /kafka_id_alloc 0 | zookeeper-shell $ZOOKEEPER_CONNECT &> /dev/null

		# Allocate an id by writing to a node and retrieving its version number.
		BROKER_ID=`echo set /kafka_id_alloc 0 | zookeeper-shell $ZOOKEEPER_CONNECT 2>&1 | grep dataVersion | cut -d' ' -f 3`

		echo "Allocated broker id ${BROKER_ID}."
	else
		echo "Using broker id ${BROKER_ID}."
	fi

	# Create the config file.
	sed -e "s|\${BROKER_ID}|$BROKER_ID|g" \
		-e "s|\${ADVERTISED_HOST_NAME}|$ADVERTISED_HOST_NAME|g " \
		-e "s|\${ZOOKEEPER_CONNECT}|$ZOOKEEPER_CONNECT|g" /kafka/templates/server.properties.template > /kakfa/config/server.properties

	cp /kafka/templates/log4j.properties /kafka/templates/tools-log4j.properties /etc/kafka
fi

cd /kafka
exec "$@"
