#!/bin/sh

grep 'TEV:' crash.log | sed 's|.*TEV:||' | tr -d ' ' > touch-input.csv
