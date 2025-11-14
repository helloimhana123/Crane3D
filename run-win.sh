#!/bin/bash
set -e

make

echo
echo
echo REMOVING PREFERENCES

rm  $APPDATA/Crane3D/Preferences.txt || true

echo
echo RUNNING PROGRAM
echo

werl.exe -pa ./ebin -run wings_start start_halt
