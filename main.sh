


#!/bin/sh



set -e



create() {

echo Setting up kv store

docker-machine create -d virtualbox kvstore > /dev/null && \

docker $(docker-machine config kvstore) run -d --net=host progrium/consul --server -bootstrap-expect 1



# store the IP address of the kvstore machine

kvip=$(docker-machine ip kvstore)



echo Creating cluster nodes

docker-machine create -d virtualbox \

--engine-opt "cluster-store consul://${kvip}:8500" \

--engine-opt "cluster-advertise eth1:2376" \

--virtualbox-boot2docker-url https://github.com/boot2docker/boot2docker/releases/download/v1.9.0/boot2docker.iso \

--swarm \

--swarm-master \

--swarm-image swarm:1.0.0 \

--swarm-discovery consul://${kvip}:8500 \

swarm-demo-1 > /dev/null &



for i in 2 3; do

docker-machine create -d virtualbox \

--engine-opt "cluster-store consul://${kvip}:8500" \

--engine-opt "cluster-advertise eth1:2376" \

--swarm \

--swarm-discovery consul://${kvip}:8500 \

--virtualbox-boot2docker-url https://github.com/boot2docker/boot2docker/releases/download/v1.9.0/boot2docker.iso \

swarm-demo-$i > /dev/null &

done

wait

}



teardown() {

docker-machine rm kvstore &

for i in 1 2 3; do

docker-machine rm -f swarm-demo-$i &

done

wait

}


test_db() {
	mysql -uadmin  -pmypass -h192.168.0.4 -P3319
}


JmeterHome=/home/hshan/exp/apache-jmeter-2.13/bin
ResultHome=/home/hshan/exp/experiments/20160202
WorkLoadHome=/home/hshan/exp/experiment/load
test_template() {
	test_name=test001
	iCon=200
	$JmeterHome/bin/jmeter -n -t $WorkloadHome/${test_name}.jmx -JpoolMax=$iCon -l $ResultHome/${test_name}.jtl -j $ResultHome/${test_name}.log
}

case $1 in
	db)	
		test_db
		;;
	test)
		test_template
		;;
	up)
		create
		;;

	down)
		teardown
		;;
		*)
	
	echo "I literally can't even..."
	exit 1
		;;
esac

