#!/bin/sh

. /home/pi/webhooks/notify-minecraft-nickname.sh
nick=$(player2name $1)

if [ -z "$nick" ] ; then
  nick="Unknown player"
fi

amixer -c 0 -- sset 'Headphone' playback -24dB
play "/home/pi/levelup.ogg"
amixer -c 0 -- sset 'Headphone' playback -6dB
pico2wave -w /dev/shm/player.wav "$nick" && aplay /dev/shm/player.wav

echo -n $(date) >> /home/pi/.notify-minecraft.log
echo " args:$0 $1 $2 $3 $4 $5" >> /home/pi/.notify-minecraft.log
