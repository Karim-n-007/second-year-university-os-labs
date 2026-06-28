#!/bin/bash
a=$1
b=$2
c=$3
max=$a

if [[ "$max" -le "$b" ]]
then max=$b
fi

if [[ "$max" -le "$c" ]]
then max=$c
fi

echo $max
