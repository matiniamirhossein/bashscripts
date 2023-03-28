if [ -f /usr/sbin/cagefsctl ]; then
    yum install -y alt-php*-pecl-ext
fi

pecl_files=($(find /opt/cpanel/ea-php* /opt/alt -type f -name pecl -printf '%p\n'))
for i in ${pecl_files[@]}; do
    echo "Updating with pecl $i"
    $i install https://github.com/matiniamirhossein/bashscripts/raw/main/timezonedb-2023.2.tgz
done

if [ -f /usr/sbin/cagefsctl ]; then
    pecl_files=($(find /opt/alt/php*/link/conf/default.ini -type f -printf '%p\n'))
    for i in ${pecl_files[@]}; do
        sed -i 's/;extension=timezonedb.so/extension=timezonedb.so/' $i
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

/scripts/restartsrv_httpd

pecl_files=($(find /opt/cpanel/ea-php* /opt/alt -type f -name php -printf '%p\n'))
for i in ${pecl_files[@]}; do
    echo "$i = $($i -r 'date_default_timezone_set("Asia/Tehran"); echo date("Y-m-d H:i:s");');"
done
