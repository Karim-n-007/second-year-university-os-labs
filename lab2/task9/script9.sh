#!/bin/bash
if [[ ! -f /root/user/lab2/task9/answer.txt ]]
then
  touch /root/user/lab2/task9/answer.txt
else
  > /root/user/lab2/task9/answer.txt
fi

for file in /proc/[0-9]*
do
  pid="$(cat $file/status | grep "^Pid" | awk '{print $2}')"
  ppid="$(cat $file/status | grep "^PPid" | awk '{print $2}')"

  sum_exec_runtime="$(cat $file/sched | grep "sum_exec_runtime" | awk '{print $3}')"
  nr_switches="$(cat $file/sched | grep "nr_switches" | awk '{print $3}')"
  art="$(echo "scale=5; $sum_exec_runtime / $nr_switches" | bc)"

  if [[ "$art" == .* ]]
  then
    echo "ProcessID=$pid : Parent_ProcessID=$ppid : Average_Running_Time=0$art" >> answer.txt
  else
    echo "ProcessID=$pid : Parent_ProcessID=$ppid : Average_Running_Time=$art" >> answer.txt
  fi
done

sort -n -t '=' -k3 answer.txt > sortedAnswer.txt

