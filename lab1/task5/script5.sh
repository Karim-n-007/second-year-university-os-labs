#!/bin/bash
touch info.log
echo >info.log

while read line
do
  arr=()
  for word in $line
  do
    arr+=($word)
  done

  secondField="${arr[3]}"
  firstCharactersSecondField="${secondField:0:4}"
  upperSecondField="${firstCharactersSecondField^^}"

  if [[ "$upperSecondField" == "INFO" ]]; then
    echo $line >>info.log
  fi

done < /var/log/syslog
