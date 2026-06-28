#!/bin/bash
pidWithMaxMemory="-1"
currentMaxMemory=0

for filePath in /proc/[0-9]*
do
  size="$(cat $filePath/status | grep "VmRSS" | awk '{print $2}')"
  pid="$(cat $filePath/status | grep "^Pid" | awk '{print $2}')"
  if [[ $size -ge $currentMaxMemory ]]
  then
    currentMaxMemory="$size"
    pidWithMaxMemory="$pid"
  fi
done

echo "PID: $pidWithMaxMemory, Mem: $currentMaxMemory"
