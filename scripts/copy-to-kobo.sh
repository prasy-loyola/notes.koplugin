#!/bin/bash
set -xe
KOBOHOST=kobo
luac -p *.lua
scp *.lua *.csv $KOBOHOST:/mnt/onboard/.adds/koreader/plugins/notes.koplugin/
