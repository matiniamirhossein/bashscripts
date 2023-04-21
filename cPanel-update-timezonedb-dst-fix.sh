if [ -f /usr/sbin/cagefsctl ]; then
    yum install -y alt-php*-pecl-ext
fi

yum install -y e2fsprogs

php_bin_files=($(find -L /usr/local/php*/bin /opt/cpanel/ea-php* /opt/alt -type f -name php -printf '%p\n' 2>/dev/null | grep -Ev 'internal|imunify|php44|php51|php52|php53' | sort))
pecl_bin_files=($(find -L /usr/local/php*/bin /opt/cpanel/ea-php* /opt/alt -type f -name pecl -printf '%p\n' 2>/dev/null | grep -Ev 'internal|imunify|php44|php51|php52|php53' | sort))

# due to cloudlinux old package which overrides our package we have to do this

if [ -f /usr/sbin/cagefsctl ]; then
    chattr -ia /opt/alt/php*/usr/lib64/php/modules/timezonedb.so
fi

for i in ${pecl_bin_files[@]}; do
    echo "Updating with pecl $i"
    $i uninstall timezonedb
    $i install https://github.com/matiniamirhossein/bashscripts/raw/main/timezonedb-2023.2.tgz
done

if [ -f /usr/sbin/cagefsctl ]; then
    chattr +ia /opt/alt/php*/usr/lib64/php/modules/timezonedb.so
fi

if [ -d /usr/local/directadmin ]; then
    conf_directories=($(find /usr/local/php* -type d -name php.conf.d -printf '%p\n'))
    for i in ${conf_directories[@]}; do
        if [ $(grep -ri 'extension=timezonedb.so' $i | wc -l) -eq "0" ]; then
            echo "extension=timezonedb.so" >$i/timezonedb.ini
        fi
    done
fi

if [ -f /usr/sbin/cagefsctl ]; then
    pecl_files=($(find /opt/alt/php*/etc/php.d -type f -printf '%p\n' | grep -Ev 'internal|imunify|php44|php51|php52|php53'))

    for i in ${pecl_files[@]}; do
        grep -q 'extension=timezonedb.so' $i && sed -i 's/;extension=timezonedb.so/extension=timezonedb.so/' $i || echo "extension=timezonedb.so" >>$i
    done

    for i in $(selectorctl --list | awk '{print $1}'); do
        selectorctl --enable-extensions=timezonedb --version=$i
    done

    for i in $(selectorctl --list | awk '{print $1}'); do
        for username in $(selectorctl --list-users --version=$i | awk -F',' '{for(i=1;i<=NF;i++){print $i}}'); do
            selectorctl --enable-user-extensions=timezonedb --version=$i --user=$username
        done
    done

    cagefsctl -M && cagefsctl --force-update && cagefsctl --rebuild-alt-php-ini
fi

pkill -9 httpd
pkill -9 apache2
pkill -9 lshttpd
pkill -9 lsws

if [ -f /scripts/restartsrv_httpd ]; then
    /scripts/restartsrv_httpd
fi

systemctl restart httpd apache2 lshttpd lsws php-fpm*

for i in ${php_bin_files[@]}; do
    if [ "$i" = "/opt/alt/php44/usr/bin/php" ]; then
        continue
    fi

    system_now=$(TZ=Asia/Tehran date '+%Y-%m-%d %H:%M')
    php_now=$($i -r 'date_default_timezone_set("Asia/Tehran"); echo date("Y-m-d H:i");')

    echo -n "$i = $($i -r 'date_default_timezone_set("Asia/Tehran"); echo date("Y-m-d H:i");');"

    if [ "$system_now" != "$php_now" ]; then
        echo " => Error"
    else
        echo " => OK"
    fi
done
