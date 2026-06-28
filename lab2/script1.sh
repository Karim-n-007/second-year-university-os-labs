#!/bin/bash
ps axo pid,state | awk '$2 != "I" {print $1}' | tail -n +2
