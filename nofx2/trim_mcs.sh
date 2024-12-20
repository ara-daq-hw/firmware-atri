#!/bin/bash

PATTERN=:020000040020DA
LN=`grep -n "$PATTERN" $1 | cut -f1 -d:`
echo "Trimming everything before line $LN"
tail -n +$LN $1 > $2
