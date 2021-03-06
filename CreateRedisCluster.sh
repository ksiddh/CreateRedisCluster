#!/bin/bash
#THIS SCRIPT ASSUMES THAT THE REDIS SERVERS ARE UP AND RUNNING IN CLUSTER READY MODE
#IF YOU HAVE NOT DONE SO, PLEASE RUN REDIS-CLUSTER-INSTALL.SH SCRIPT FIRST
#USE IP OF EACH REDIS SERVER THAT YOU WANT TO HAVE IN CLUSTER

if [ "${#}" -ne "3" ]; then
  echo "usage: ${0} version port ip[,ip...]"
  exit 1
fi

#script parameters and defaults
VERSION="3.2.8"
REDIS_PORT=6379

VERSION=${1:-$VERSION}   # Defaults to VERSION 3.2.8
REDIS_PORT=${2:-$REDIS_PORT}   # Defaults to REDIS_PORT 6379
IFS=',' read -ra SERVER_IPS <<< "${3}"

CLUSTER_INSTANCES=""

for SERVER_IP in ${SERVER_IPS[@]}; do
  CLUSTER_INSTANCES+=" ${SERVER_IP}:${REDIS_PORT}"
done
echo ${CLUSTER_INSTANCES}

#############################################################################
log()
{
    echo "$1"
}
##############################################################################
create_cluster()
{
  # Run `find / -type d -name "*redis-3.2.8*" -print 2>/dev/null` to find the folder where redis-3.2.8 is installed
  cd /etc/redis-$VERSION # This is not right!!!!
	
	log "Creating cluster..."
	# Validate that redis-trib.rb exixts
		if [ -f src/redis-trib.rb ]; then
			echo "yes" | src/redis-trib.rb create ${CLUSTER_INSTANCES} 
		else
			echo "The redis-trib.rb is not found or ruby gem is not installed"
			exit 1;
		fi
}
##############################################################################
start_redis()
{
	# Start the Redis daemon
	if [ "`systemctl is-active redis_${REDIS_PORT}`" == "inactive" ] 
	then
		echo "redis_${REDIS_PORT} wasn't running so attempting restart"
		systemctl restart redis_${REDIS_PORT}
	fi
	echo redis_${REDIS_PORT}" is currently running"
	
	log "Redis daemon was started successfully"
}
##############################################################################
stop_redis()
{
	# Stop the Redis daemon
	systemctl stop redis_${REDIS_PORT}
	if [ "`systemctl is-active redis_${REDIS_PORT}`"!="active" ] 
	then
		echo redis_${REDIS_PORT}" is stopped"
	fi
	log "Redis daemon was stopped successfully"
}
##############################################################################
validate_redisCluster()
{
	log "Validating redis cluster..."
	cd /etc/redis-$VERSION

	for SERVER_IP in ${SERVER_IPS[@]}; do
	if [ -f src/redis-trib.rb ]; then
			src/redis-trib.rb check ${SERVER_IP}:${REDIS_PORT} | grep 'All nodes agree about slots configuration' &> /dev/null
			if [ $? == 0 ]; then
				log "Cluster configuration validated for " ${SERVER_IP}:${REDIS_PORT}
			else
				log "Please check the server and the port"
			fi 
		else
			log "The redis-trib.rb is not found or ruby gem is not installed"
		exit 1;
	fi
	log "Redis cluster successfully validated."
    done
	log "Redis cluster successfully created."
}
##############################################################################

create_cluster

stop_redis

start_redis

validate_redisCluster