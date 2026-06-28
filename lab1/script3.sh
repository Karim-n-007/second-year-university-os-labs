#!/bin/bash
readonly FIRST_ACTION_FOR_USER=1
readonly SECOND_ACTION_FOR_USER=2
readonly THIRD_ACTION_FOR_USER=3
readonly FOURTH_ACTION_FOR_USER=4

echo -e  "Введите необходимый номер:\n1) Запуск nano\n2) Запуск Vi\n3) Запуск links\n4) Выход"

while true
do
  read userNumber
  if [[ "$userNumber" -eq "$FIRST_ACTION_FOR_USER" ]]; then
    nano
  elif [[ "$userNumber" -eq "$SECOND_ACTION_FOR_USER" ]]; then
    vi
  elif [[ "$userNumber" -eq "$THIRD_ACTION_FOR_USER" ]]; then
    links
  elif [[ "$userNumber" -eq "$FOURTH_ACTION_FOR_USER" ]]; then
    exit 0
  else
    echo "Введён неверный номер. Попробуйте снова"
  fi
done

