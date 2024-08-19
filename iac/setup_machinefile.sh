#!/bin/bash

output=$(terraform output -json)

instance_ids=($(echo $output | jq -r '.instance_id.value[]'))
instance_ips=($(echo $output | jq -r '.instance_public_ip.value[]'))
instance_cpu_counts=($(echo $output | jq -r '.instance_cpu_count.value[]'))

machinefile="machinefile"

> $machinefile

for i in "${!instance_ips[@]}"; do
  ip=${instance_ips[$i]}
  cpu_count=${instance_cpu_counts[$i]}
  echo "$ip:$cpu_count" >> $machinefile
done

master=${instance_ips[0]}
scp $machinefile ec2-user@$master:~/MPIDemo/conf/

echo Master: $master
