#!/bin/bash

KOBOHOST=kobowifi

# scp kobo:/mnt/onboard/.adds/koreader/crash.log .
scp $KOBOHOST:/mnt/onboard/books/Notes/notes-test/*.png .
scp $KOBOHOST:/mnt/onboard/.adds/koreader/crash.log .

