#!/bin/bash
logsDirectory="/root/user/lab1/task6/logsCopy"

if [[ ! -d "logsCopy" ]]; then
  mkdir logsCopy
fi

if [[ ! -f "full.log" ]]; then
  touch full.log
else
  rm full.log
  touch full.log
fi

if [[ "$1" == "test" ]]; then
  if [[ -f "$logsDirectory/syslog" ]]; then
    rm "$logsDirectory/syslog"
    cp "/var/log/syslog" "$logsDirectory"
  else
    cp "/var/log/syslog" "$logsDirectory"
  fi
else
  if [[ -f "$logsDirectory/syslog" ]]; then
    rm "$logsDirectory/syslog"
  fi
fi

for filePath in /var/log/*.log
do
  fileName="${filePath##*/}"

  if [[ -f "$logsDirectory/$fileName" ]]; then
    continue
  else
    cp $filePath $logsDirectory
  fi
done


for file in /root/user/lab1/task6/logsCopy/*
do
  while read line
  do
    if [[ "$line" == *"Warning"* ]]; then
      echo "$line" >> "full.log"
    fi
  done < "$file"
done


for file in /root/user/lab1/task6/logsCopy/*
do
  sed -i "s/INFO/Information/g" "$file"
  sed -i "s/WARNING/Warning/g" "$file"

  while read line
  do
    if [[ "$line" == *"Information"* ]]; then
      echo "$line" >> "full.log"
    fi
  done < "$file"
done
