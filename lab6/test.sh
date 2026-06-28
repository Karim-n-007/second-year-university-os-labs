#!/bin/bash
M=$1; cd "$M" || exit 1

echo "=== create + write ===" ; echo "hello" > f
echo "=== getattr ===" ; stat f
echo "=== read ===" ; cat f
echo "=== readdir ===" ; ls
echo "=== mkdir ===" ; mkdir d
echo "=== rename ===" ; mv d d2
echo "=== rmdir ===" ; rmdir d2
echo "=== chmod ===" ; chmod 644 f
echo "=== chown ===" ; chown "$(whoami)" f
echo "=== utimens ===" ; touch f
echo "=== truncate ===" ; truncate -s 0 f
echo "=== symlink ===" ; ln -s f sym
echo "=== readlink ===" ; readlink sym
echo "=== link ===" ; ln f hard
echo "=== statfs ===" ; df .
echo "=== unlink ===" ; rm f sym hard