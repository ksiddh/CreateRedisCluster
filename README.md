# CreateRedisCluster
This script creates redis cluster ( with master nodes only )

# Usage
bash createrediscluster.sh version port ip[,ip...]

# Assumptions and cavets
1. you have created redis servers aware of the version, port and ip addresses
2. you want to create a cluster with just masters (no redundancy)

# This to fix:
1. get the location of /redis<version>/src (Line 34: # Run `find / -type d -name "*redis-3.2.8*" -print 2>/dev/null` to find the folder where redis-3.2.8 is installed)
  2. Add ability to add slaves to the master
