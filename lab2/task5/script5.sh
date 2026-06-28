#!/bin/bash
s="$(ps axo pid,etimes | tail -n +2)"

echo "$1"

while read key val
do
  if [[ $val -le $1 ]]
  then
    kill $val
    echo $key >> "killed.log"
  fi
done <<< $s

