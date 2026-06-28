#!/bin/bash
ps ax -o pid,%mem --sort=-%mem | tail +2
