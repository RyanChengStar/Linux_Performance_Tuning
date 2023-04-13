#!/bin/bash

MIN_FREE_KBYTES_SYSCTL=$(egrep ^vm.min_free_kbytes /etc/sysctl.conf | awk '{print $3}')
MIN_FREE_KBYTES_MEMORY=$(cat /proc/sys/vm/min_free_kbytes)
NUMA_NODE_COUNT=$(numactl --hardware | grep available: | awk '{print $2}')
TOTAL_MEMORY_KBYTES=$(free -k | awk '/Mem:/ {print $2}')
NUMA_BASED=$(( $NUMA_NODE_COUNT * 1048576 ))
MEMORY_BASED=$(( $TOTAL_MEMORY_KBYTES / 200 ))
if [[ $NUMA_BASED -ge $MEMORY_BASED ]]
then
	RECOMMEND_VALUE=$NUMA_BASED
else
	RECOMMEND_VALUE=$MEMORY_BASED
fi
OFFSET=$(echo $RECOMMEND_VALUE*.05 | bc | cut -d"." -f1)
LOWER_BOUND=$(echo $RECOMMEND_VALUE-$OFFSET | bc)
UPPER_BOUND=$(echo $RECOMMEND_VALUE+$OFFSET | bc)
if [[ $MIN_FREE_KBYTES_SYSCTL -ge LOWER_BOUND && $MIN_FREE_KBYTES_SYSCTL -le UPPER_BOUND ]]
then
	SYSCTL_IN_RANGE=YES
else
	SYSCTL_IN_RANGE=NO
fi
#sysctl in range?
if [[ $MIN_FREE_KBYTES_MEMORY -ge LOWER_BOUND && $MIN_FREE_KBYTES_MEMORY -le UPPER_BOUND ]]
then
	MEMORY_IN_RANGE=YES
else
	MEMORY_IN_RANGE=NO
fi
DETAIL=$(
echo -e "Total Memory:       $TOTAL_MEMORY_KBYTES";
echo -e "NUMA node count:    $NUMA_NODE_COUNT";
echo -e "NUMA calculated:    $NUMA_BASED";
echo -e "memory calculated:  $MEMORY_BASED";
echo -e "recommended value:  $RECOMMEND_VALUE";
echo -e "permitted range:    $LOWER_BOUND to $UPPER_BOUND";
echo -e "in sysctl.conf:     $MIN_FREE_KBYTES_SYSCTL";
echo -e "sysctl in range?:   $SYSCTL_IN_RANGE";
echo -e "in active memory:   $MIN_FREE_KBYTES_MEMORY";
echo -e "memory in range?:   $MEMORY_IN_RANGE";
)
if [[ $SYSCTL_IN_RANGE = YES && $MEMORY_IN_RANGE = YES ]]
then
	echo -e "SUCCESS: vm.min_free_kbytes is configured as recommended.  Details:\n\n$DETAIL"
elif [[ $MIN_FREE_KBYTES_SYSCTL -lt $LOWER_BOUND || $MIN_FREE_KBYTES_MEMORY -lt $LOWER_BOUND ]]
then
	echo -e ":: Result : 【FAILURE】: vm.min_free_kbytes is not configured as recommended"
	ZZT_V1=$(( $NUMA_NODE_COUNT * 1 * 1024 * 1024 ))
	ZZT_V2=$(( $TOTAL_MEMORY_KBYTES * 5 /10 / 100 ))
	if [ $ZZT_V1 -gt $ZZT_V2 ]
	then
	ZZT_MAX=$ZZT_V1
	else
	ZZT_MAX=$ZZT_V2
	fi
	ZZT_MAX_GB=$(($ZZT_MAX/1024/1024))
	echo ">>> if output is ，please vi sysctl.conf and edit param's value for:vm.min_free_kbytes and reboot"
	echo ">>> [formula_oracle]vm.min_free_kbytes value (Kb) =MAX(1GB * number_numa_nodes, 0.5% * total_memory) "
	echo ">>> [calculated_zzt]vm.min_free_kbytes = $ZZT_MAX   (About: $ZZT_MAX_GB GB)"
	ZZT_V3=32
	ZZT_V4=$(($TOTAL_MEMORY_KBYTES/1024/1024))
	if [ $ZZT_V4 -gt $ZZT_V3 ]
	then
		echo ">>> [PASS]The current memory is suitable for setting system parameters."
	else
		echo ">>> [WARN]Your memory is too small to set this parameter."
	fi
	echo -e "Details:\n\n$DETAIL"
elif  [[ $MIN_FREE_KBYTES_SYSCTL -gt $UPPER_BOUND && $MIN_FREE_KBYTES_MEMORY -gt $UPPER_BOUND ]]
then
  echo -e "WARNING: vm.min_free_kbytes is not configured as recommended.  Details:\n\n$DETAIL"
else
  echo -e "ERROR: Inconsistent results.  Details:\n\n$DETAILS"
fi