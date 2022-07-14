#!/bin/bash
path="monitor.txt"
errorPath="error_monitor.txt"
cat /dev/null > $path
cat /dev/null > $errorPath
errorCount=0
cpu_rate=95
disk_rate=80
mem_rate=80
function get_server_info() {
	#获取时间
	check_time=$(date +%Y年%m月%d日%H时%M分)

	#获取主机名
	system_hostname=$(hostname | awk '{print $1}')

	#获取服务器IP
	address=$(/sbin/ip a|grep "global"|awk '{print $2}' |awk -F/ '{print $1}')

	#获取服务器系统版本
	os_version=$(cat /etc/issue | awk '{print $1" "$2}')

	#获取网关
	gateway=$(ip route |awk 'NR==1'| awk '{print $3}')

	#获取DNS
	DNS=$(cat /etc/resolv.conf|grep nameserver |tail -1| awk '{print $2}')

	echo -e "巡检时间：${check_time} \n" >> $path

	echo -e "服务器IP: ${address} \n" >> $path

	echo -e "网关: ${gateway} \n" >> $path

	echo -e "DNS：${DNS} \n" >> $path

	echo -e "系统版本:" ${os_version} '\n'>> $path

	ping 114.114.114.114 -c 3 &> /dev/null

	if [ $? -eq 0 ];then
           echo -e "服务器外网连通: 【正常】\n" >> $path
	else
	   let errorCount+=1
           echo -e "服务器外网无法连通: 【异常】\n" >> $errorPath
        fi

	echo -e "-----------------------------------\n">> $path

}

function check_cpu_usage() {

	Cpu_num=`grep processor /proc/cpuinfo|wc -l`

	Cpu_use=`w | awk 'NR==1{print int($10)}'`

	load_1=`uptime | awk '{print $10}' | sed -e 's/\,//g' | awk -F " " '{print $1}'`

	load_5=`uptime | awk '{print $11}' | sed -e 's/\,//g' | awk -F " " '{print $1}'`

	load_15=`uptime | awk '{print $12}'`

	echo -e CPU 平均1分钟负载：$load_1 "\n" >> $path
	echo -e CPU 平均5分钟负载：$load_5 "\n" >> $path
	echo -e CPU 平均15分钟：$load_15 "\n" >> $path

	if [[ ${Cpu_use} -lt ${cpu_rate} ]] 

	then
	    echo -e "CPU使用率巡检结果：【正常】\n" >> $path

	else
	    let errorCount+=1
	    echo -e "CPU使用率超出阀值：【异常】\n" >> $errorPath
	fi
	
	echo -e "-----------------------------------\n">> $path

}

function check_disk_usage(){

	disk_partation=`df -Th | awk 'BEGIN{OFS="="}/^\/dev/{print $NF,int($6)}'`
	flag="false"
	for disk in $disk_partation
	do
	    p_name=${disk%=*}
	    disk_usage=${disk#*=}
	    echo -e "磁盘分区：$p_name，使用率：$disk_usage% \n" >> $path

	    if [[ ${disk_usage} -gt ${disk_rate} ]]
	    then
		flag="true"
	        echo -e "分区${p_name}使用率超出阀值：【异常】\n" >> $errorPath
	    else
	        echo -e "分区${p_name}使用率巡检结果：【正常】\n" >> $path
	    fi
	done
	if [ $flag == "true" ];then
	   sed -i "1i磁盘空间超出阀值：【异常】\n" $errorPath
	   let errorCount+=1
	fi

	echo -e "-----------------------------------\n">> $path

}

function check_mem_usage() {

	#获取总内存

	mem_total=$(free -m | grep Mem| awk -F " " '{print $2}')

	#获取已用内存

	mem_use=$(free -m | grep Mem| awk -F " " '{print $3}')

	#获取可用内存

	mem_free=$(free -m | grep "Mem" | awk '{print $7}')

	#内存阈值

	echo -e '\n'>> $path

	PERCENT=$(printf "%d%%" $(($mem_use*100/$mem_total)))

	PERCENT_1=$(echo $PERCENT|sed 's/%//g')

	if [[ $PERCENT_1 -gt ${mem_rate} ]]

	then
	        let errorCount+=1
		echo -e "总内存大小：$mem_total MB\n">> $path

		echo -e "已用内存：$mem_use MB\n" >> $path

		echo -e "内存剩余大小：$mem_free MB\n" >> $path

		echo -e "内存使用率：$PERCENT\n" >> $path

		echo -e "内存使用率超出阀值：【异常】\n\n" >> $errorPath

	else

		echo -e "总内存大小：$mem_total MB\n">> $path

		echo -e "已用内存：$mem_use MB\n" >> $path

		echo -e "内存剩余大小：$mem_free MB\n" >> $path

		echo -e "内存使用率：$PERCENT\n" >> $path

		echo -e "内存使用情况巡检结果：【正常】\n" >> $path

	fi
	
	echo -e "-----------------------------------\n">> $path

}

function check_url(){
	website="https://www.baidu.com/"
    wget --spider -q -o /dev/null  --tries=1 -T 5 ${website}
    if [ $? -eq 0 ]
    then
            echo -e "网页 $website \n" >> $path
            echo -e "网页巡检：【正常】\n" >> $path
    else
    	    let errorCount+=1
            echo -e "网页 $website \n" >> $path
            echo -e "网页巡检：【异常】\n" >> $errorPath

    fi

}

function go_execute(){
	get_server_info
	check_cpu_usage
	check_disk_usage
	check_mem_usage
	check_url
	if [ $errorCount -gt 0 ];then
           let normal=5-$errorCount
	   sed -i "1i\共检测5条项目,异常$errorCount条,正常${normal}条\n" $errorPath
	   cat $errorPath
       exit 1
	else
	   sed -i "1i\共检测5条项目,全部正常\n" $path	
	   echo -e "共检测5条项目,全部正常\n"	
	   #cat $path
	fi
}

go_execute
