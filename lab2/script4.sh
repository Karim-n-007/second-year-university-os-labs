#!/bin/bash
sleep 10000 &
pid=$! #1
dir="/proc/$pid"

cat "$dir/stack" | tail -n 5 #2

echo "--------------------------"

grep -E 'Name|PPid|Kthread|Threads' "/proc/$pid/status" #3

#4: в Linux нет 'процессов' есть потоки. Есть task и каждый поток - отдельный task со своим ID. 
# pid в status - id конкретного task
# tgid (thread gropup id) - id группы потоков, как бы тот 'процесс'. У одного процесса может быть несколько потоков,
# у всех них общий Tgid, а у каждого потока свой id (TID - Thread id)
# sleep 10000 & - однопоточная программа, и этот один поток является thread group leader, а исторически сложилось, что у лидера TID = TGID
