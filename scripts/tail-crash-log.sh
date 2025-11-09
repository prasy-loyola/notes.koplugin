#!/bin/bash

KOBOHOST=kobo

ssh $KOBOHOST 'tail /mnt/onboard/.adds/koreader/crash.log -f'

