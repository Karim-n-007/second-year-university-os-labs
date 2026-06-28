#!/bin/bash
homeDirectory=($HOME)
currentDirectory=$(pwd)

if [[ "$homeDirectory" == "$currentDirectory" ]]
then
  echo $homeDirectory
  exit 0
else
  echo "Ваша текущая директория не соответствует домашней" >&2
  exit 1
fi
