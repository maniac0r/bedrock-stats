#!/bin/bash
# 2020-03-08 by maniac
# 1. gather network traffic on Bedrock default port (19132)
#    publish gathered data to /var/log/syslog file (for filebeat ingestion) and if URL variable defined, also to influxdb
#    you can customize additional or other port configuring INPUT variable line simply by modifying the tcpdump pcap filter
# 2. watch for player connect/disconnects events from docker
#

URL="http://127.0.0.1:8086/write?db=opentsdb"
AUTH=""						# use -u USER:PASS format (e.g. AUTH="-u mylogin:mypassword)
INTERFACE="docker0"				# interface we should listen for bedrock traffic (use eth0 if unsure)
BEDROCKNET="172.17.0.0/24"                      # network range of your bedrock server (use this to filter out outgoing traffic from bedrock server as we want to see only incoming traffic)
DELAY=60                			# seconds to sleep before next tcpdump iteration
WINDOW=$(((DELAY + 5)))

OIFS=$IFS
NLIFS="
"

IFS=$NLIFS

sniffer() {
  while true ; do
    IFS=$NLIFS
    DATA=""

#    INPUT=$(/usr/sbin/tcpdump -t -n -i docker0 -c 100 port 19132 and not src net 172.17.0.0/24 2>/dev/null | awk '{print $2}' | awk -F '.' '{print $1"."$2"."$3"."$4" "$5}' | sort -n | uniq -c)
    INPUT=$( /usr/sbin/tcpdump -G 9 -W 1 -n -i $INTERFACE -s 0 -w - port 19132 and not src net $BEDROCKNET 2>/dev/null | /usr/sbin/tcpdump -n -r - 2>/dev/null | awk '{print $3}' | awk -F '.' '{print $1"."$2"."$3"."$4" "$5}' | sort -n | uniq -c )

    while read -r LINE ; do 
      #echo "DEBUG TCPDUMP LINE:#${LINE}#"
      IFS=$OIFS
      PACKETS=$(echo $LINE | awk '{print $1}')
      IP=$(echo $LINE | awk '{print $2}')
      PORT=$(echo $LINE | awk '{print $3}')
      if [ -n "$PACKETS" ] && [ -n "$IP" ] && [ -n "$PORT" ] ; then					# if we actually got any usable data
        echo "BedrockMinecraft Stats: PACKETS:${PACKETS} IP:${IP} PORT:${PORT}"
        if [ -n "${DATA}" ] ; then
         DATA=$DATA$'\nmetric=bedrock_packets packets='"$PACKETS"',ip='\"$IP\"',port='"$PORT"
        else
          DATA='metric=bedrock_packets packets='"$PACKETS"',ip='\"$IP\"',port='"$PORT"
        fi
        #echo "DATA:$DATA"
        IFS=$NLIFS
        curl -s $AUTH -X POST --data "$DATA" "$URL"
      fi
      IFS=$NLIFS
    done <<< "$INPUT"
    sleep $DELAY
  done
}

log_parser() {
  unset ACTION
  unset DATA
  unset VALUE
  
  R_CONN="Player\ connected:"
  R_DISCONN="Player\ disconnected:"
  
  I=0
  CONNECTED=0
  DISCONNECTED=0
  IFS=$NLIFS

 docker logs -f --since ${WINDOW}s bedrock 2>/dev/null | egrep --line-buffered '.*' | \
  while read -r LINE ; do
    LINE=$(echo "$LINE" | sed 's/ \[/\n/g' | tr -d \] | tr -d \[ )
    #echo "debug: got docker log line:$LINE"
    unset ACTION
    [[ "$LINE" =~ $R_CONN ]] && ACTION="connected" && VALUE=1 #&& echo "CONN"
    [[ "$LINE" =~ $R_DISCONN ]] && ACTION="disconnected" && VALUE=0 #&& echo "DISCONN"

    if [ -n "$ACTION" ] ; then
      PLAYER=$(echo "$LINE" | sed 's/.*connected: //' | sed 's/, xuid.*//' | sed 's/ /\\ /g')
      XUID=$(echo "$LINE" | sed 's/.*xuid: //')
      TS=$(echo "$LINE" | sed 's/ INFO.*//' | xargs -n1 -I%% date -d 'TZ="UTC" %%' +"%s")	# bedrock provides timestamp in UTC so convert it to local TZ
      #echo "$TS:$ACTION:$PLAYER:$XUID"
      if [ -n "${DATA}" ] ; then
        DATA=$DATA$'\nbedrock_player_activity,tagplayer='$PLAYER',tagxuid='$XUID',tagaction='$ACTION' value='${VALUE}' '$TS'000000000'
      else
        DATA='bedrock_player_activity,tagplayer='$PLAYER',tagxuid='$XUID',tagaction='$ACTION' value='${VALUE}' '$TS'000000000'
      fi
      #echo "DATA:#$DATA#"
      IFS=$NLIFS
      [ -n "$DATA" ] && echo "DATA:$DATA" && curl -s $AUTH -X POST --data "$DATA" "$URL"
      unset DATA
      #[ -n "$DATA" ] && curl -s $AUTH -X POST --data "$DATA" "$URL"
    fi
  done
    
}


sniffer &
while true ; do
  log_parser
  echo "debug: due to some reason - next run..."
  #sleep $DELAY
  sleep 1
done
