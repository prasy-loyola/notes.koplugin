#!/bin/bash

KOBOHOST=kobowifi
scp *.lua $KOBOHOST:/mnt/onboard/.adds/koreader/plugins/notes.koplugin/
scp *.lua *.csv $KOBOHOST:/mnt/onboard/.adds/koreader/plugins/notes.koplugin/
