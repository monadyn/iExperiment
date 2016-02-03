


#!/bin/sh



set -e


unit() {
	echo  'ut'
	cal $(date +"%m %Y") | awk 'NF {DAYS = $NF}; END {print DAYS}'

}


JmeterHome=/home/hshan/exp/apache-jmeter-2.13/bin
ResultHome=/home/hshan/exp/experiments
WorkloadHome=/home/hshan/exp/iExperiment/load
CVSHeadFile=$ResultHome/head.csv
WorkHome=/home/hshan/exp/iExperiment

test_template() {

	current_day=$(date | awk '{print $2$3}')
	#right_now=$(date +"%x %r %Z")
	echo $current_day
	ResultHome=/home/hshan/exp/experiments/$current_day
	
	if [ ! -d "$ResultHome" ]
	then mkdir "$ResultHome"
	fi

	#for conc in 100 200 400 800 1600
	for conc in 1600
	do
		echo 
		echo 'start: '$conc
		test_name=${conc}_200000_browse

		#ssh node3  collectl -scmdn -i 0.1 -P -f $test_name -oTm  
		#echo ssh node3 "collectl -scmdn -i 0.1 -P -f ./collectl_tmp/$test_name -oTm &"		
		echo 'collectl -P -sms -p /var/log/collectl/cag-dl380-01-20070830-082013.raw.gz --from 08:29-08:30'
		#echo "collectl -scmdn -i 0.1 -P -f ./collectl_tmp/$test_name -oTm &" > srv_collectl.sh		
		echo "collectl -P -scmdn -i 0.1 -f ./collectl_tmp/$test_name -oz &" > srv_collectl.sh		
		#scp srv_collectl.sh node3:~
		#ssh node3 'bash -s' <  ~/srv_collectl.sh
		ssh node3 rm -f ~/collectl_tmp/${test_name}*
		ssh node3 'bash -s' <  ./srv_collectl.sh &


		workload_file=$WorkloadHome/${test_name}.jmx 
		echo $workload_file
		echo $JmeterHome/jmeter -n -t $WorkloadHome/${test_name}.jmx -JpoolMax=$conc -l $ResultHome/${test_name}.jtl -j $ResultHome/${test_name}.log
		rm -f ${test_name}.jtl ${test_name}.log
		$JmeterHome/jmeter -n -t $WorkloadHome/${test_name}.jmx -JpoolMax=$conc -l $ResultHome/${test_name}.jtl -j $ResultHome/${test_name}.log

		ssh node3 pkill collectl
		scp node3:~/collectl_tmp/${test_name}* .
	done
}

total_request=200
analyze () {


	current_day=$(date | awk '{print $2$3}')
	echo $current_day
	ResultHome=/home/hshan/exp/experiments/$current_day
	result_file_list=''

	for conc in 100 200 400 800 1600
	do
		echo 
		echo 'start: '$conc
		test_name=${conc}_200000_browse
		rm -f $WorkHome/${test_name}.csv
		cut_line="${total_request}q"
		echo $cut_line
		echo "cat $CVSHeadFile $ResultHome/${test_name}.jtl | sed -e '$cut_line' >  $WorkHome/${test_name}.csv"
		cat $CVSHeadFile $ResultHome/${test_name}.jtl | sed -e '200000q' >  $WorkHome/${test_name}.csv
		result_file_list="$result_file_list ${test_name}.csv"
	done
	echo python plot_result.py $result_file_list
	python plot_result.py $result_file_list
}


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




case $1 in
	db)	
		test_db
		;;
	test)
		test_template
		;;
	anal)
		analyze
		;;
	ut)
		unit
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

