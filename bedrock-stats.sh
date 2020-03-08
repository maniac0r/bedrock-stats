#!/bin/bash
# 2020-03-08 by maniac
# gather network traffic on Bedrock default port (19132)
# publish gathered data to /var/log/syslog file (for filebeat ingestion) and if URL variable defined, also to influxdb
# you can customize additional or other port configuring INPUT variable line simply by modifying the tcpdump pcap filter 
#

URL="http://127.0.0.1:8086/write?db=opentsdb"	# make sure to configure hostname/IP address of your InfluxDB server here. Make empty to skip sending data to influxdb
AUTH=""						# use -u USER:PASS format (E.g. AUTH="-u mylogin:mypassword)
INTERFACE="docker0"				# interface we should listen for bedrock traffic (use eth0 if unsure)
BEDROCKNET="172.17.0.0/24"			# network range of your bedrock server (use this to filter out outgoing traffic from bedrock server as we want to see only incoming traffic)
DELAY=60					# seconds to sleep before next iteration


OIFS=$IFS
NLIFS="
"

IFS=$NLIFS

while true ; do
  IFS=$NLIFS
  DATA=""

  INPUT=$(/usr/sbin/tcpdump -t -n -i $INTERFACE -c 100 port 19132 and not src net $BEDROCKNET 2>/dev/null | awk '{print $2}' | awk -F '.' '{print $1"."$2"."$3"."$4" "$5}' | sort -n | uniq -c)

  while read -r LINE ; do 
    #echo "DEBUG LINE:#${LINE}#"
    IFS=$OIFS
    PACKETS=$(echo $LINE | awk '{print $1}')
    IP=$(echo $LINE | awk '{print $2}')
    PORT=$(echo $LINE | awk '{print $3}')
    echo "BedrockMinecraft Stats: PACKETS:${PACKETS} IP:${IP} PORT:${PORT}"
    if [ -n "${DATA}" ] ; then
     DATA=$DATA$'\nmetric=bedrock_packets packets='"$PACKETS"',ip='\"$IP\"',port='"$PORT"
    else
      DATA='metric=bedrock_packets packets='"$PACKETS"',ip='\"$IP\"',port='"$PORT"
    fi
    #echo "DEBUG DATA: $DATA"
    IFS=$NLIFS
    if [ -n "$URL" ] ; then
      curl -s $AUTH -X POST --data "$DATA" "$URL"
    fi
  done <<< "$INPUT"

  sleep $DELAY
done
