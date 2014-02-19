#!/bin/bash

SUM=0
for x in `slabtop -s c -o | tail -n +8 | awk '{print $7}' | sed 's/K//'`; do
  SUM=$(( $SUM + $x ))
done
SLABS=$SUM

SUM=0
for x in `ps aux | tail -n +2 | awk '{print $6}'`; do
  SUM=$(( $SUM + $x ))
done
RSS=$SUM

USED=`free -k | grep buffers/cache | awk '{print $3}'`
ACTUALUSED=$(( $USED - $SLABS ))

echo "\"Used\" RAM:      $(( $USED / 1024 )) MB"
echo "RSS total:       $(( $RSS / 1024 )) MB"
echo "Slab cache:      $(( $SLABS / 1024 )) MB"
echo "Actual used RAM: $(( $ACTUALUSED / 1024 )) MB"
