# CreateRedisCluster
This script creates redis cluster ( with master nodes only )

# Usage
**bash createrediscluster.sh version port ip[,ip...]**

# Assumptions and cavets
1. you have created redis servers and you're aware of the *version, port and ip addresses*
2. you want to create a cluster with just masters (no redundancy)

# Things to fix:
- get the location of /redis<version>/src (Line 34: # Run `find / -type d -name "*redis-3.2.8*" -print 2>/dev/null` to find the folder where redis-3.2.8 is installed)
- Add ability to add slaves to the master

# TEST performed: 
## *Assuming there are 2 slaves attached to a single master. In my setup, I had 9 masters and each had 2 slaves ( Total of 27 servers)*

# Tools:
    Following are some tools used to perform testing (needs ruby gem to be installed on each server)-
 # redis-rb-cluster-master        
        - wget https://github.com/antirez/redis-rb-cluster/archive/master.zip
        - unzip master.zip
        - cd redis-rb-cluster-master
        - This tool is used to input random keys into the cluster, prints them out : usage "redis-rb-cluster-master ruby example.rb"
        - This tool also supports writing huge amount of data to redis and check whether previously written data is still there: usage "redis-rb-cluster-master ruby consistency-test.rb <IP> 6379"
      `output: 
      850 R (0 err) | 850 W (0 err) | 
      4682 R (0 err) | 4682 W (0 err) |
      ...
      where 850 reads and 850 writes have happened without any error. If there is any error, the tool will list the errors.`
# redis-benchmark
      - The tool is located at /etc/redis-3.2.8/src/ on all the servers
      - This tool is used to execute performance tests on the cluster by simulating the number of parallel connections, number of requests, payload, commands etc.
      usage: " redis-benchmark -c 1000 -n 600000 -r 600000 -d 5000 -t set,get -P 16 -q" where -c is the number of parallel connections, n is the total number of requests (default 100000), r is Use random keys for SET/GET/INCR,
      d is Data size of SET/GET value in bytes (default 2), t is Only run the comma separated list of tests. The test names are the same as the ones produced as output, P is Pipeline requests, q is quiet mode (Displays the results in the end)
      - Check redis-benchmark to get a detailed explanation for the usage https://redis.io/topics/benchmarks
 # redis-trib
      - The tool is located at /etc/redis-3.2.8/src/ on all the servers
      - This tool is used to create cluster, add node, delete node, reshard, fix the cluster, re-balance etc.
      - Check redis-trib.rb help for detailed explanation for the usage
      - Note: The tool does not support hostname. We have to use IP of the host
# redis-cli
    - This is the most important tool and comes with redis installation. More details in 'useful Redis Commands' section.
  1. Useful Redis Commands:
Debugging commands
    * redis logs are located on each server (master and slaves) at /var/log/redis_6379.log. (tail -f /var/log/redis-6379.log)
    * redis-cli slowlog get 10 - This will return any commands that took longer than 10ms. It also returns the timestamp when it happened and time in microseconds
    * redis-cli --latency - This will give the current network latency. Note: Not recommended for prod
    * redis-cli info - This is a single most important command and gives the state of the Server, clients, Memory, stats, CPU, Keyspace, commandstats, replication, cluster (https://redis.io/commands/INFO)
    * redis-cli --stat - will give the most important details in real-time view 
    * redis-cli dbsize - will give the cache size on each server
    * redis-cli -p 6379 cluster nodes | grep myself - will give my node Id, connected slaves count etc.
    * redis-cli -p 6379 cluster nodes - will give information about the cluster, master nodes, slaves nodes, master/slave relationship etc.
    * redis-cli client list | sed -n 's|.*addr=\(.*\)\:.*|\1|p' | sort | uniq -c - will give the number of connections by each node
    * redis-cli client list - Displays all the clients connected with their state (active, idle)
    * redis-cli monitor - Displays the operation happening on server in realtime
    * redis-cli -c -p 6379, followed by set <key> <Value>
    * redis-cli cluster nodes
    * ./redis-trib.rb check <IP>:6379
    * ./redis-trib.rb add-node --slave new_nodes_ip:6379 master_node_ip:6379
    * redis-cli --bigkeys
    2. To get the size of any record
    * redis-cli -c -p 6379
      get <Key>
      debug object <Key>
    * redis-cli -c -p 6379 strlen <Key> - This will give the length of the value stored at the key
    * redis-cli -p 6379 debug segfault - This will crash the master on which it is run. This tool is useful for failover testing
    * redis-cli INFO stats |egrep "^total_"
    * redis-cli INFO keyspace
    For exhaustive list of commands - https://redis.io/commands

------------------------------------------------------------------------------------------------------------------------------
# Tests - 
## *After the cluster has been created, following are the set of tests that should be executed to validate the cluster*
# Basic Tests: GET AND SET operation on the cluster
    - Connect to any Redis master or slave. Run "redis-cli -c -p 6379" followed by command Set <Key> <Value> or SETEX <Key> <Value> <TTL>
    - The response should be " Redirected to slot [10114] located at <IP>:6379"
    - Perform Get operation as get <Key>
    - The response should be "Redirected to slot [12136] located at <IP>:6379"
# Basic Test: Cluster view test
    - Connect to any Redis master or slave server. Run  "redis-cli cluster nodes"
    - The response will contain the set of known nodes, the state of the connection we have with such nodes, their flags, properties and assigned slots.
    - Make sure that each master has 2 slaves attached to it.
# Basic Test: Info about the cluster (state of the Server, clients, Memory, stats, CPU, Keyspace, commandstats, replication, cluster)
    - Connect to any Redis master or slave server. Run  "redis-cli info all"
    - The response will display information about Server,Memory, CPU, replication, keyspaces etc.
    - Make sure that role is "slave" if you run redis-cli command on the slave machine or "master" if run on master server
# Performance or Benchmark test:
    - Execute "redis-benchmark -c 1000 -n 600000 -r 600000 -d 5000 -t set,get". 
    - This will give the GET and SET operations/sec
     - Execute "redis-benchmark -c 1000 -n 600000 -r 600000 -d 5000 -t set,get -P 16"
    - This will give the GET and SET operations/sec where P is pipeline requests. The value of GET AND SET in this case will be higher than previous one.
    - Execute the benchmark tool with various values of 'd' : 
    - More information here - https://redis.io/topics/benchmarks

# Cluster Fail-over tests (Automated)
    - Use Putty to open connections to master and slaves (e.g. 2 masters and 4 slaves)
    - Run "redis-cli cluster nodes" and take a snapshot of the master and slaves configuration
    - Run the "redis-rb-cluster-master ruby consistency-test.rb <IP> 6379" on one of the master terminal
    - Leave the tool running
    - On another terminal (master), run "redis-cli -p 6379 debug segfault". Before running, make sure to note the slaves attached to this master 
    - The command will crash the master (stop the redis service)
    - On the terminal running "ruby consistency-test.rb" tool, we should expect to see errors that the master is not found and within a short span, normal operation should resume.
    - Run "redis-cli cluster nodes" and take a snapshot of the master and slaves configuration. We will find that a slave has been promoted as master.
    - Start the redis service on the box with "systemctl start redis_6379"
    - Run "redis-cli cluster nodes" and take a snapshot of the master and slaves configuration. We will see that after the server/service comes online, it is no longer master but has been added as a slave.

# Cluster Fail-over tests (Manual) - Safer
    - From https://redis.io/topics/cluster-tutorial#testing-the-failover -
    - Sometimes it is useful to force a failover without actually causing any problem on a master. For example in order to upgrade the Redis process of one of the master nodes it is a good idea to failover it in order to turn it into a slave with minimal impact on availability.
    - Manual failovers are supported by Redis Cluster using the CLUSTER FAILOVER command, that must be executed in one of the slaves of the master you want to failover.
    - Manual failovers are special and are safer compared to failovers resulting from actual master failures, since they occur in a way that avoid data loss in the process, by switching clients from the original master to the new master only when the system is sure that the new master processed all the replication stream from the old one.
    - This is what you see in the slave log when you perform a manual failover:

    #Manual failover user request accepted.
    #Received replication offset for paused master manual failover: 347540
    #All master replication stream processed, manual failover can start.
    #Start of election delayed for 0 milliseconds (rank #0, offset 347540).
    #Starting a failover election for epoch 7545.
    #Failover election won: I'm the new master.

    - Basically clients connected to the master we are failing over are stopped. At the same time the master sends its replication offset to the slave, that waits to reach the offset on its side. When the replication offset is reached, the failover starts, and the old master is informed about the configuration switch. When the clients are unblocked on the old master, they are redirected to the new master.


#TROUBLESHOOTING and fixing slave issues
- We want the slaves to be equally distributed amongst the master i.e. Each master should have 2 slaves in different zones but sometimes, the master will be in failed state(blame openstack). What this means is that the failover takes places and one of the slaves attached to the failed master is promoted to master. Now the new master will have just one slave as shown below. Also when we restart the server (failed master), it will start as slave and may or may not join the previous master. In this scenario, we will have a master that has 1 slave and another master that has 3 slaves. The topology needs to be balanced.

    -  Select a slave (based on zone) to be detached from the master having 3 slaves
    - Login to the slave and run 'redis-cli CLUSTER RESET' - This command will take time as it removes the slave from the cluster and also flushes the DB. 
    - Once the command completes, run 'redis-cli cluster info' and it will return a master with no slaves ( not connected to any cluster )
    - Login to the master and find 'redis-trib.rb' tool. COMMAND: find / -type d -name "*redis-3.2.8*" -print 2>/dev/null
    - Run './redis-trib.rb add-node --slave 10.36.189.135:6379 10.36.183.191:6379' where thrid IP and port is the slave that we detached above and fourth is master where we are running this command
    - You will see the following after running ^^

    - On Master run 'redis-cli cluster nodes | grep myself' to get the nodeID
    - On Slave run 'redis-cli CLUSTER REPLICATE nodeID'  where nodeID is that of the master obtained above.
    - The above command will return OK after completion.
    - In the Kibana graph you will see that the number of slaves on all the nodes (masters) in the cluster is 2.
