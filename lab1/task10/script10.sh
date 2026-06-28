#!/bin/bash
declare -A map
text="$(man bash | col -b)"
pathToOutputFile="/root/user/lab1/task10/fileForOutput.txt"

if [[ -f "$pathToOutputFile" ]]; then
  rm "$pathToOutputFile"
  touch "$pathToOutputFile"
else
  touch "$pathToOutputFile"
fi

text="$(echo "$text" | tr -d '[:punct:]')"

for word in $text
do
  if [[ "${#word}" -ge 4 ]]; then
    ((map[$word]++))
  fi
done

for key in "${!map[@]}"
do
  echo "$key ${map[$key]}">>$pathToOutputFile
done

sort -k2 -n $pathToOutputFile | tail -n 3
