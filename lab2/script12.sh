data="$(ps axo pid,etimes,ni | tail -n +2)"
delta="$2"
while read pid etimes ni
do
  if [[ "$ni" == "-" ]]
  then
    continue
  fi

  if [[ $etimes -ge $1 ]]
  then
      nice=$(echo "$ni + $2" | bc)
      renice $nice -p $pid
  fi
done <<< "$data"


