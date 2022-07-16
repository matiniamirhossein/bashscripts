#!/bin/bash
#
# Checks the Named Configuration then
# Checks all zones in the named.conf
#
# Written by Troy Germain modified by Amirhossein Matini

# Base location of named configuration file
NAMEDCONF="/etc/named.conf"

# Base Path to the Zone Files
ZONEBASE="/var/named/"

# Command Path for named- commands
COMPATH="/usr/sbin/"

#CHROOT location if applicable, if not just use null definition
#CHROOT=""

eval FILES=( $(sed -e 's/;/;\n/g' -e 's/^[ \t]*//' ${CHROOT}${NAMEDCONF} | grep [[:blank:]]file | grep -v '^//' | awk -F\" '{printf "%s ", $(NF-1)}') )

${COMPATH}named-checkconf -z > /dev/null 2>&1
if [[ $? != 0 ]]; then
    echo "named.conf Configuration Check Failed!, errors:"
    named-checkconf -z 1>/dev/null
    exit 1
fi

echo "Named Config Test Passed"

for (( LOOP=0; LOOP<${#FILES[*]}; LOOP=LOOP+1 )); do
    domain=$(basename ${FILES[${LOOP}]} .db)
    if [[ $domain = "named.ca" ]]; then
        continue
    fi
    result=$(${COMPATH}named-checkzone $domain ${FILES[${LOOP}]})
    if [[ $? != 0 ]]; then
        echo "Check Failed! - $domain against ${FILES[${LOOP}]}"
        echo $result
	exit 1
    fi
done

echo "All Zone Files pass"

echo "All OK - Safe to Reload!!"
