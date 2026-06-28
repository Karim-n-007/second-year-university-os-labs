#!/bin/bash
arr=()
read userInput

while [ "$userInput" != "q" ]
do
arr+=("$userInput")
read userInput
done

echo "${arr[@]}, ${#arr[@]}"
