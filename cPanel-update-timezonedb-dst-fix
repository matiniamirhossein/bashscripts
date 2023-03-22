#!/bin/bash

pecl_files=($(find /opt/cpanel/ea-php*/root/usr/bin/pecl /opt/alt/ -type f -name pecl -printf '%p\n'))
for i in ${pecl_files[@]}
do
    echo "Updating with pecl $i"
    printf "\n" | $i install timezonedb
done

if [ -f /usr/sbin/cagefsctl ]
then
    cagefsctl -M && cagefsctl --force-update && cagefsctl --rebuild-alt-php-ini
fi

/scripts/restartsrv_httpd
