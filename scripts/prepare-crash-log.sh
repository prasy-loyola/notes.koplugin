#!/bin/bash

vi -Es \
    -c '%v/DEBUG input event/d' \
    -c '%s/.*type: //' \
    -c '%s/ (.*code: /,/' \
    -c '%s/ (.*value: /,/' \
    -c '%s/ time: //' \
    -c 'wq' \
    crash.log
