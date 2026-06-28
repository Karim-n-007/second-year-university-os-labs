#!/bin/bash
if [[ -f "emails.lst" ]]; then
  rm emails.lst
  touch emails.lst
else
  touch emailst.lst
fi

for fileName in /etc/*
do
  if [[ -f "$fileName" ]]; then
    while read line
      do
	for word in $line
	do
          if [[ "$word" =~ [a-zA-Z0-9\.-_]+@[a-zA-Z0-9\.-_]+\.[a-zA-Z0-9\.-_] ]]; then
	    echo "$word">>"emails.lst"
	  fi
	done
      done < "$fileName"
  fi
done
