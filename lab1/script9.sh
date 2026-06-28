#!/bin/bash
count=0
for fileName in /var/log/*
do
  if [[ "$fileName" == *\.log ]]; then
    while read line
    do
     ((count++))
    done < "$fileName"
  fi
done
echo $count
