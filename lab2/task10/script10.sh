#!/bin/bash
prevFilePath="/root/user/lab2/task9/sortedAnswer.txt"
currentFilePath="/root/user/lab2/task10/sortedAnswer.txt"

cp "$prevFilePath" "$currentFilePath"

prevPpid="0"
processWithTheSameParentProccesIdCount=0
sumAverageRunningTimeWithTheSameParentProcessId=0

while read str
do
  ParentProcess="$(echo $str | grep -o -E "Parent_ProcessID=[0-9]+")"
  Ppid="$(echo $ParentProcess | cut -d '=' -f 2)"
  currentAverageRunningTime="$(echo $str | grep -o -E "Average_Running_Time=[0-9]*\.?[0-9]+" | cut -d '=' -f 2)"

if [[ "$prevPpid" != "$Ppid" ]]
  then
    M=$(echo "scale=5; $sumAverageRunningTimeWithTheSameParentProcessId / $processWithTheSameParentProcessIdCount" | bc)
    if [[ $M == .* ]]
    then M="0$M"
    fi
    sed -i "/$str/i\\Average_Running_Children_of_ParentID=$prevPpid is $M" "$currentFilePath"

    prevPpid="$Ppid"
    processWithTheSameParentProcessIdCount=0
    sumAverageRunningTimeWithTheSameParentProcessId=0
  fi

  ((processWithTheSameParentProcessIdCount++))
  sumAverageRunningTimeWithTheSameParentProcessId=$(echo "scale=5; $sumAverageRunningTimeWithTheSameParentProcessId + $currentAverageRunningTime" | bc)
done < "$prevFilePath"

M=$(echo "scale=5; $sumAverageRunningTimeWithTheSameParentProcessId / $processWithTheSameParentProcessIdCount" | bc)
if [[ $M == .* ]]
then M="0$M"
fi
sed -i "\$a\\Average_Running_Children_of_ParentID=$prevPpid is $M" "$currentFilePath"

#ProcessID=1 : Parent_ProcessID=0 : Average_Running_Time=0.25714
