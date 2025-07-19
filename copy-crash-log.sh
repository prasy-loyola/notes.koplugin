#!/bin/bash

KOBOHOST=kobowifi

# scp root@192.168.99.250:/mnt/onboard/.adds/koreader/crash.log .
# scp kobo:/mnt/onboard/.adds/koreader/crash.log .
scp $KOBOHOST:/mnt/onboard/books/Notes/notes-test/*.png .
scp $KOBOHOST:/mnt/onboard/.adds/koreader/crash.log .

