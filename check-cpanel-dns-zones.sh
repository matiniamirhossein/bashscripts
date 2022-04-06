#!/bin/bash
#
# Checks the Named Configuration then
# Checks all zones in the named.conf
#
# Written by Troy Germain

# Base location of named configuration file
NAMEDCONF="/etc/named.conf"

# Base Path to the Zone Files
ZONEBASE="/var/named/"

# Command Path for named- commands
COMPATH="/usr/sbin/"

#CHROOT location if applicable, if not just use null definition
#CHROOT=""

eval FILES=( $(sed -e 's/^[ \t]*//' ${CHROOT}${NAMEDCONF} | grep ^file | grep -v '^//' | awk -F\" '{printf "%s ", $(NF-1)}') )

${COMPATH}named-checkconf
if [[ $? != 0 ]]; then
    echo "named.conf Configuration Check Failed!"
    exit 1
fi

echo "Named Config Test Passed"

# Loop starts at 1 instead of 0 because of definition for named.ca
for (( LOOP=1; LOOP<${#FILES[*]}; LOOP=LOOP+1 )); do
    domain=$(basename ${FILES[${LOOP}]} .db)
    if [[ $domain = "named.ca" ]]; then
        continue
    fi
    ${COMPATH}named-checkzone $domain ${FILES[${LOOP}]} > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "Check Failed! - $domain against ${FILES[${LOOP}]}"
        exit 1
    fi
done

echo "All Zone Files pass"

echo "All OK - Safe to Reload!!"
