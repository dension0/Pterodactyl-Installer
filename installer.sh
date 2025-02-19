#!/bin/bash
#!/usr/bin/env bash

########################################################################
#                                                                      #
#            Pterodactyl Installer, Updater, Remover and More          #
# Copyright 2023, dension - Silverhost.hu, <madarasz.laszlo@gmail.com> #
# https://github.com/dension0/Pterodactyl-Installer/edit/main/LICENSE  #
#                  based on Malthe K, <me@malthe.cc>                   #
# https://github.com/guldkage/Pterodactyl-Installer/blob/main/LICENSE  #
#                                                                      #
#  This script is not associated with the official Pterodactyl Panel.  #
#  You may not remove this line                                        #
#                                                                      #
########################################################################

### VARIABLES ###

dist="$(. /etc/os-release && echo "$ID")"

### OUTPUTS ###

function trap_ctrlc ()
{
    echo "Bye!"
    exit 2
}
trap "trap_ctrlc" 2

warning(){
    echo -e '\e[31m'"$1"'\e[0m';

}

### CHECKS ###

if [[ $EUID -ne 0 ]]; then
    echo ""
    echo "[!] Sorry, but you need to be root to run this script."
    echo "Most of the time this can be done by typing sudo su in your terminal"
    exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
    echo ""
    echo "[!] cURL is required to run this script."
    echo "To proceed, please install cURL on your machine."
    echo ""
    echo "Debian based systems: apt install curl"
    echo "CentOS: yum install curl"
    exit 1
fi

### Pterodactyl Panel Installation ###

send_summary(){
    clear
    if [ -d "/var/www/pterodactyl" ] 
    then
        echo ""
        warning "[!] WARNING: There seems to already be a installation of Pterodactyl installed! This script will fail!"
        echo ""
        echo "[!] Summary:"
        echo "    Panel URL: $FQDN"
        echo "    Webserver: $WEBSERVER"
        echo "    SSL: $SSLSTATUS"
        echo "    Username: $USERNAME"
        echo "    First name: $FIRSTNAME"
        echo "    Last name: $LASTNAME"
        echo "    Password: $USERPASSWORD"
        echo ""
    else
        echo ""
        echo "[!] Summary:"
        echo "    Panel URL: $FQDN"
        echo "    Webserver: $WEBSERVER"
        echo "    SSL: $SSLSTATUS"
        echo "    Username: $USERNAME"
        echo "    First name: $FIRSTNAME"
        echo "    Last name: $LASTNAME"
        echo "    Password: $USERPASSWORD"
        echo ""
    fi
}

panel(){
    echo ""
    echo "[!] Before installation, we need some information."
    echo ""
    panel_webserver
}

finish(){
    clear
    cd
    echo -e "Summary of the installation\n\nPanel URL: $FQDN\nWebserver: $WEBSERVER\n\nPANEL ADMIN\nUsername: $USERNAME\nFirst name: $FIRSTNAME\nLast name: $LASTNAME\nPassword: $USERPASSWORD\n\nDatabase user for PANEL user\nUsername for PANEL: pterodactyluser\nDatabase password for PANEL: $DBPASSWORD\n\nDatabase user for HOST\nUsername for Database Host: pterodactyl\nPassword for Database Host: $DBPASSWORDHOST" >> /root/panel_credentials.txt

    echo "[!] Installation of Pterodactyl Panel done"
    echo ""
    echo "    Summary of the installation" 
    echo "    Panel URL: $FQDN"
    echo "    Webserver: $WEBSERVER"
    echo "    SSL: $SSLSTATUS"
    echo "    Username: $USERNAME"
    echo "    First name: $FIRSTNAME"
    echo "    Last name: $LASTNAME"
    echo "    Password: $USERPASSWORD"
    echo "" 
    echo "    Database user for PANEL"
    echo "    Database username: pterodactyluser"
    echo "    Database password: $DBPASSWORD"
    echo "" 
    echo "    Database user for HOST"
    echo "    Database username: pterodactyl"
    echo "    Password for Database Host: $DBPASSWORDHOST"
    echo "" 
    echo "    These credentials has been saved in a file called" 
    echo "    panel_credentials.txt in directory of root user"
    echo ""
    echo "    Would you like to install Wings too? (Y/N)"
    read -r WINGS_ON_PANEL

    if [[ "$WINGS_ON_PANEL" =~ [Yy] ]]; then

        wings
    fi
    if [[ "$WINGS_ON_PANEL" =~ [Nn] ]]; then
        exit 1
    fi
}

panel_webserver(){
    send_summary
    echo "[!] Select Webserver"
    echo "    (1) NGINX"
    echo "    (2) Apache"
    echo "    Input 1-2"
    read -r option
    case $option in
        1 ) option=1
            WEBSERVER="NGINX"
            panel_fqdn
            ;;
        2 ) option=2
            WEBSERVER="Apache"
            panel_fqdn
            ;;
        * ) echo ""
            echo "Please enter a valid option from 1-2"
    esac
}

panel_conf(){
    [ "$SSLSTATUS" == true ] && appurl="https://$FQDN"
    [ "$SSLSTATUS" == false ] && appurl="http://$FQDN"
    mysql -u root -e "CREATE USER 'pterodactyluser'@'localhost' IDENTIFIED BY '$DBPASSWORDHOST';" && mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'pterodactyluser'@'localhost' WITH GRANT OPTION;"
    mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASSWORD';" && mysql -u root -e "CREATE DATABASE panel;" &&mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;" && mysql -u root -e "FLUSH PRIVILEGES;"
    php artisan p:environment:setup --author="$EMAIL" --url="$appurl" --timezone="CET" --telemetry=false --cache="redis" --session="redis" --queue="redis" --redis-host="localhost" --redis-pass="null" --redis-port="6379" --settings-ui=true
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="$DBPASSWORD"
    php artisan migrate --seed --force
    php artisan p:user:make --email="$EMAIL" --username="$USERNAME" --name-first="$FIRSTNAME" --name-last="$LASTNAME" --password="$USERPASSWORD" --admin=1
    chown -R www-data:www-data /var/www/pterodactyl/*
    curl -o /etc/systemd/system/pteroq.service https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/pteroq.service
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
    sudo systemctl enable --now redis-server
    sudo systemctl enable --now pteroq.service
    if [ "$SSLSTATUS" = "true" ] && [ "$WEBSERVER" = "NGINX" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        ln -s /etc/nginx/sites-enabled/pterodactyl.conf /etc/nginx/sites-available/pterodactyl.conf

        systemctl stop nginx
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start nginx
        finish
        fi
    if [ "$SSLSTATUS" = "true" ] && [ "$WEBSERVER" = "Apache" ]; then
        a2dissite 000-default.conf && systemctl reload apache2
        curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/pterodactyl-apache-ssl.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
        apt install libapache2-mod-php
        sudo a2enmod rewrite
        sudo a2enmod ssl
        systemctl stop apache2
        certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
        systemctl start apache2
        finish
        fi
    if [ "$SSLSTATUS" = "false" ] && [ "$WEBSERVER" = "NGINX" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        ln -s /etc/nginx/sites-enabled/pterodactyl.conf /etc/nginx/sites-available/pterodactyl.conf
        systemctl restart nginx
        finish
        fi
    if [ "$SSLSTATUS" = "false" ] && [ "$WEBSERVER" = "Apache" ]; then
        a2dissite 000-default.conf && systemctl reload apache2
        curl -o /etc/apache2/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/pterodactyl-apache.conf
        sed -i -e "s@<domain>@${FQDN}@g" /etc/apache2/sites-enabled/pterodactyl.conf
        sudo a2enmod rewrite
        systemctl stop apache2
        systemctl start apache2
        finish
        fi
}

panel_install(){
    echo "" 
    if  [ "$dist" =  "ubuntu" ]; then
        apt-get update
        apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        apt update
        sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"
        apt install certbot -y

        apt -y install mariadb-server tar unzip git redis-server
        apt -y install php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        mkdir /var
        mkdir /var/www
        mkdir /var/www/pterodactyl
        cd /var/www/pterodactyl
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
        tar -xzvf panel.tar.gz
        chmod -R 755 storage/* bootstrap/cache/
        cp .env.example .env
        command composer install --no-dev --optimize-autoloader --no-interaction
        php artisan key:generate --force

        if  [ "$WEBSERVER" =  "NGINX" ]; then
            apt install nginx -y
            panel_conf
            fi
        elif  [ "$WEBSERVER" =  "Apache" ]; then
            apt install apache2 libapache2-mod-php -y
            panel_conf
            fi
    if  [ "$dist" =  "debian" ]; then
        apt-get update
        apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL  https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
        curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
        apt update -y
        apt install certbot -y

        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bas
        apt install -y mariadb-server tar unzip git redis-server
        apt -y install php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip}
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        pause 0.5s
        mkdir /var
        mkdir /var/www
        mkdir /var/www/pterodactyl
        cd /var/www/pterodactyl
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
        tar -xzvf panel.tar.gz
        chmod -R 755 storage/* bootstrap/cache/
        cp .env.example .env
        command composer install --no-dev --optimize-autoloader --no-interaction
        php artisan key:generate --force
        if  [ "$WEBSERVER" =  "NGINX" ]; then
            apt install nginx -y
            panel_conf
            fi
        elif  [ "$WEBSERVER" =  "Apache" ]; then
            sudo apt install apache2 libapache2-mod-php8.1 -y
            panel_conf
            fi
}

panel_summary(){
    clear
    DBPASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    USERPASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    DBPASSWORDHOST=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    echo ""
    echo "[!] Summary:"
    echo "    Panel URL: $FQDN"
    echo "    Webserver: $WEBSERVER"
    echo "    SSL: $SSLSTATUS"
    echo "    Username: $USERNAME"
    echo "    First name: $FIRSTNAME"
    echo "    Last name: $LASTNAME"
    echo "    Password: $USERPASSWORD"
    echo "" 
    echo "    Database user for PANEL user"
    echo "    Database username: pterodactyluser"
    echo "    Database password: $DBPASSWORD"
    echo "" 
    echo "    Database user for HOST user"
    echo "    Database username: pterodactyl"
    echo "    Password for Database Host: $DBPASSWORDHOST"
    echo "" 
    echo "    These credentials has been saved in a file called" 
    echo "    panel_credentials.txt in directory of root user"
    echo "" 
    echo "    Do you want to start the installation? (Y/N)" 
    read -r PANEL_INSTALLATION

    if [[ "$PANEL_INSTALLATION" =~ [Yy] ]]; then
        panel_install
    fi
    if [[ "$PANEL_INSTALLATION" =~ [Nn] ]]; then
        echo "[!] Installation has been aborted."
        exit 1
    fi
}

panel_fqdn(){
    send_summary
    echo "[!] Please enter FQDN. You will access Panel with this."
    read -r FQDN
    [ -z "$FQDN" ] && echo "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        echo ""
        echo "Your FQDN does not resolve to the IP of this machine."
        echo "Continuing anyway in 10 seconds.. CTRL+C to stop."
        sleep 10s
        panel_ssl
    else
        panel_ssl
    fi
}

panel_ssl(){
    send_summary
    echo "[!] Do you want to use SSL for your Panel? This is recommended. (Y/N)"
    read -r SSL_CONFIRM

    if [[ "$SSL_CONFIRM" =~ [Yy] ]]; then
        SSLSTATUS=true
        panel_email
    fi
    if [[ "$SSL_CONFIRM" =~ [Nn] ]]; then
        SSLSTATUS=false
        panel_email
    fi
}

panel_email(){
    send_summary
    if  [ "$SSLSTATUS" =  "true" ]; then
        echo "[!] Please enter your email. It will be shared with Lets Encrypt and being used to setup this Panel."
        fi
    if  [ "$SSLSTATUS" =  "false" ]; then
        echo "[!] Please enter your email. It will used to setup this Panel."
        fi
    read -r EMAIL
    panel_username
}

panel_username(){
    send_summary
    echo "[!] Please enter username for admin account."
    read -r USERNAME
    panel_firstname
}
panel_firstname(){
    send_summary
    echo "[!] Please enter first name for admin account."
    read -r FIRSTNAME
    panel_lastname
}
panel_lastname(){
    send_summary
    echo "[!] Please enter last name for admin account."
    read -r LASTNAME
    panel_summary
}

### Pterodactyl Wings Installation ###

wings(){
    clear
    apt install dnsutils -y
    echo ""
    echo "[!] Before installation, we need some information."
    echo ""
    wings_fqdn
}

wings_fqdnask(){
    echo "[!] Do you want to install a SSL certificate? (Y/N)"
    echo "    If yes, you will be asked for an email."
    echo "    The email will be shared with Lets Encrypt."
    read -r WINGS_SSL

    if [[ "WINGS_SSL" =~ [Yy] ]]; then
        panel_fqdn
    fi
    if [[ "$SSL_CONFIRM" =~ [Nn] ]]; then
        WINGS_FQDN_STATUS=false
        wings_full
    fi
}

wings_full(){
    if  [ "$WINGS_FQDN_STATUS" =  "true" ]; then
        systemctl stop nginx
        apt install -y certbot && certbot certonly --standalone -d $WINGS_FQDN --staple-ocsp --no-eff-email --agree-tos

        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        systemctl enable --now docker

        mkdir -p /etc/pterodactyl || exit || echo "An error occurred. Could not create directory." || exit
        apt-get -y install curl tar unzip
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/wings.service
        chmod u+x /usr/local/bin/wings
        clear
        echo ""
        echo "[!] Pterodactyl Wings successfully installed."
        echo "    You still need to setup the Node"
        echo "    on the Panel and restart Wings after."
        echo ""
        fi
    if  [ "$WINGS_FQDN_STATUS" =  "false" ]; then
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        systemctl enable --now docker

        mkdir -p /etc/pterodactyl || exit || echo "An error occurred. Could not create directory." || exit
        apt-get -y install curl tar unzip
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        curl -o /etc/systemd/system/wings.service https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/wings.service
        chmod u+x /usr/local/bin/wings
        clear
        echo ""
        echo "[!] Pterodactyl Wings successfully installed."
        echo "    You still need to setup the Node"
        echo "    on the Panel and restart Wings after."
        echo ""
        fi
}

wings_fqdn(){
    echo "[!] Please enter your FQDN if you want to install a SSL certificate. If not, press enter and leave this blank."
    read -r WINGS_FQDN
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${WINGS_FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        echo ""
        echo "FQDN cancelled. Either FQDN is incorrect or you left this blank."
        WINGS_FQDN_STATUS=false
        wings_full
    else
        WINGS_FQDN_STATUS=true
        wings_full
    fi
}

### PHPMyAdmin Installation ###

phpmyadmin(){
    apt install dnsutils -y
    echo ""
    echo "[!] Before installation, we need some information."
    echo ""
    phpmyadmin_fqdn
}

phpmyadmin_finish(){
    cd
    echo -e "PHPMyAdmin Installation\n\nSummary of the installation\n\nPHPMyAdmin URL: $PHPMYADMIN_FQDN\nPreselected webserver: NGINX\nSSL: $PHPMYADMIN_SSLSTATUS\nEmail: $PHPMYADMIN_EMAIL\n\nPHPMyAdmin SQL user\nUser: $PHPMYADMIN_USER_LOCAL\nPassword: $PHPMYADMIN_USER_PWD\n\nTo finish PHPMyAdmin settings do bellow steps:\n1. Log in on $PHPMYADMIN_FQDN website with the details above.\n2. Go to the phpmyadmin database.\n3. In the top menu bar, click on the 'Settings' menu item.\n4. In the warning bar that appears, click on the 'Find out why' link.\n5. In the warning bar that appears, click on the 'create' link and import the basic tables\nThat's all." > /root/phpmyadmin_credentials.txt
    clear
    echo "[!] Installation of PHPMyAdmin done"
    echo ""
    echo "    Summary of the installation" 
    echo "    PHPMyAdmin URL: $PHPMYADMIN_FQDN"
    echo "    Preselected webserver: NGINX"
    echo "    SSL: $PHPMYADMIN_SSLSTATUS"
    echo "    Email: $PHPMYADMIN_EMAIL"
    echo ""
    echo "    PHPMyAdmin SQL user"
    echo "    User: $PHPMYADMIN_USER_LOCAL"
    echo "    Password: $PHPMYADMIN_USER_PWD"
    echo ""
    echo "    These credentials will has been saved in a file called" 
    echo "    phpmyadmin_credentials.txt in directory of root user"
    echo ""
    echo "    Please, read credentials and follow and follow the"
    echo "    instructions there to finish setting up PHPMyAdmin."
}


phpmyadminweb(){
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "true" ]; then
        rm -rf /etc/nginx/sites-enabled/default
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/phpmyadmin-ssl.conf || exit || echo "An error occurred. cURL is not installed." || exit
        sed -i -e "s@<domain>@${PHPMYADMIN_FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf || exit || echo "An error occurred. NGINX is not installed." || exit
        ln -s /etc/nginx/sites-enabled/phpmyadmin.conf /etc/nginx/sites-available/phpmyadmin.conf
        systemctl stop nginx || exit || echo "An error occurred. NGINX is not installed." || exit
        certbot certonly --standalone -d $PHPMYADMIN_FQDN --staple-ocsp --no-eff-email -m $PHPMYADMIN_EMAIL --agree-tos || exit || echo "An error occurred. Certbot not installed." || exit
        systemctl start nginx || exit || echo "An error occurred. NGINX is not installed." || exit

        apt install mariadb-server
        PHPMYADMIN_USER_PWD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
        mysql -u root -e "CREATE USER '$PHPMYADMIN_USER_LOCAL'@'localhost' IDENTIFIED BY '$PHPMYADMIN_USER_PWD';" && mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$PHPMYADMIN_USER_LOCAL'@'localhost' WITH GRANT OPTION;"
        mysql -u root -e "create database phpmyadmin"

        BLOWFISH_SECRET=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        curl -o /var/www/phpmyadmin/config.inc.php https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/phpmyadminconfig.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        sed -i -e "s@<blowfish_secret>@${BLOWFISH_SECRET}@g" /var/www/phpmyadmin/config.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        sed -i -e "s@<controluser>@${PHPMYADMIN_USER_LOCAL}@g" /var/www/phpmyadmin/config.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        sed -i -e "s@<controlpass>@${PHPMYADMIN_USER_PWD}@g" /var/www/phpmyadmin/config.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        chown -R www-data:www-data config.inc.php
        chmod 660 config.inc.php
        rm -rf /var/www/phpmyadmin/phpMyAdmin-*-all-languages/
        rm -rf /var/www/phpmyadmin/phpMyAdmin-latest-all-languages.tar.gz
        rm -rf /var/www/phpmyadmin/boodark-1.1.0.zip
        rm -rf /var/www/phpmyadmin/config.sample.inc.php
        rm -rf /var/www/phpmyadmin/config
        rm -rf /var/www/phpmyadmin/setup
    
        phpmyadmin_finish
        fi
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "false" ]; then
        rm -rf /etc/nginx/sites-enabled/default || exit || echo "An error occurred. NGINX is not installed." || exit
        curl -o /etc/nginx/sites-enabled/phpmyadmin.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/phpmyadmin.conf || exit || echo "An error occurred. cURL is not installed." || exit
        sed -i -e "s@<domain>@${PHPMYADMIN_FQDN}@g" /etc/nginx/sites-enabled/phpmyadmin.conf || exit || echo "An error occurred. NGINX is not installed." || exit
        ln -s /etc/nginx/sites-enabled/phpmyadmin.conf /etc/nginx/sites-available/phpmyadmin.conf
        systemctl restart nginx || exit || echo "An error occurred. NGINX is not installed." || exit

        apt install mariadb-server
        PHPMYADMIN_USER_PWD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
        mysql -u root -e "CREATE USER '$PHPMYADMIN_USER_LOCAL'@'localhost' IDENTIFIED BY '$PHPMYADMIN_USER_PWD';" && mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$PHPMYADMIN_USER_LOCAL'@'localhost' WITH GRANT OPTION;"
        mysql -u root -e "create database phpmyadmin"

        BLOWFISH_SECRET=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
        curl -o /var/www/phpmyadmin/config.inc.php https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/phpmyadminconfig.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        sed -i -e "s@<blowfish_secret>@${BLOWFISH_SECRET}@g" /var/www/phpmyadmin/config.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        sed -i -e "s@<controluser>@${PHPMYADMIN_USER_LOCAL}@g" /var/www/phpmyadmin/config.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        sed -i -e "s@<controlpass>@${PHPMYADMIN_USER_PWD}@g" /var/www/phpmyadmin/config.inc.php || exit || echo "An error occurred. PHPMyAdmin is not installed." || exit
        chown -R www-data:www-data config.inc.php
        chmod 660 config.inc.php
        rm -rf /var/www/phpmyadmin/phpMyAdmin-*-all-languages/
        rm -rf /var/www/phpmyadmin/phpMyAdmin-latest-all-languages.tar.gz
        rm -rf /var/www/phpmyadmin/boodark-1.1.0.zip
        rm -rf /var/www/phpmyadmin/config.sample.inc.php
        rm -rf /var/www/phpmyadmin/config
        rm -rf /var/www/phpmyadmin/setup
    
        phpmyadmin_finish
        fi
}

phpmyadmin_fqdn(){
    send_phpmyadmin_summary
    echo "[!] Please enter FQDN. You will access PHPMyAdmin with this."
    read -r PHPMYADMIN_FQDN
    [ -z "$PHPMYADMIN_FQDN" ] && echo "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${PHPMYADMIN_FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        echo ""
        echo "Your FQDN does not resolve to the IP of this machine."
        echo "Continuing anyway in 10 seconds.. CTRL+C to stop."
        sleep 10s
        phpmyadmin_ssl
    else
        phpmyadmin_ssl
    fi
}

phpmyadmininstall(){
    if  [ "$dist" =  "ubuntu" ]; then
        apt install nginx certbot -y
        mkdir /var/www/phpmyadmin && mkdir /var/www/phpmyadmin/tmp/ || exit || echo "An error occurred. Could not create directory." || exit
        cd /var/www/phpmyadmin

        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        apt -y install php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip,bz2}
        wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
        tar xzf phpMyAdmin-latest-all-languages.tar.gz
        mv /var/www/phpmyadmin/phpMyAdmin-*-all-languages/* /var/www/phpmyadmin
        wget https://files.phpmyadmin.net/themes/boodark/1.1.0/boodark-1.1.0.zip
        unzip -qq boodark-1.1.0.zip -d /var/www/phpmyadmin/themes/
        chown -R www-data:www-data *
    
        phpmyadminweb
        fi
    if  [ "$dist" =  "debian" ]; then
        apt install nginx certbot -y
        mkdir /var/www/phpmyadmin && mkdir /var/www/phpmyadmin/tmp/ || exit || echo "An error occurred. Could not create directory." || exit
        cd /var/www/phpmyadmin
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
        curl -fsSL  https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg
        apt update -y

        apt-get update
        apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release
        apt-add-repository universe
        apt install -y php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,bz2}

        wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
        tar xzf phpMyAdmin-latest-all-languages.tar.gz
        mv /var/www/phpmyadmin/phpMyAdmin-*-all-languages/* /var/www/phpmyadmin
        wget https://files.phpmyadmin.net/themes/boodark/1.1.0/boodark-1.1.0.zip
        unzip -qq boodark-1.1.0.zip -d /var/www/phpmyadmin/themes/
        chown -R www-data:www-data *
         
        phpmyadminweb
        fi
}


phpmyadmin_summary(){
    clear
    echo ""
    echo "[!] Summary:"
    echo "    PHPMyAdmin URL: $PHPMYADMIN_FQDN"
    echo "    Preselected webserver: NGINX"
    echo "    SSL: $PHPMYADMIN_SSLSTATUS"
    echo "    Email: $PHPMYADMIN_EMAIL"
    echo ""
    echo "    PHPMyAdmin SQL user"
    echo "    User: $PHPMYADMIN_USER_LOCAL"
    echo "    Password: IT WILL BE GENERATED AUTOMATICALLY"
    echo ""
    echo "    These credentials have been saved in a file called" 
    echo "    phpmyadmin_credentials.txt in directory of root user"
    echo "" 
    echo "    Do you want to start the installation? (Y/N)" 
    read -r PHPMYADMIN_INSTALLATION

    if [[ "$PHPMYADMIN_INSTALLATION" =~ [Yy] ]]; then
        phpmyadmininstall
    fi
    if [[ "$PHPMYADMIN_INSTALLATION" =~ [Nn] ]]; then
        echo "[!] Installation has been aborted."
        exit 1
    fi
}



send_phpmyadmin_summary(){
    clear
    if [ -d "/var/www/phpymyadmin" ] 
    then
        echo ""
        warning "[!] WARNING: There seems to already be a installation of PHPMyAdmin installed! This script will fail!"
        echo ""
        echo "[!] Summary:"
        echo "    PHPMyAdmin URL: $PHPMYADMIN_FQDN"
        echo "    Preselected webserver: NGINX"
        echo "    SSL: $PHPMYADMIN_SSLSTATUS"
        echo "    Email: $PHPMYADMIN_EMAIL"
        echo ""
        echo "    PHPMyAdmin SQL user"
        echo "    User: $PHPMYADMIN_USER_LOCAL"
        echo "    Password: IT WILL BE GENERATED AUTOMATICALLY"
        echo ""
    else
        echo ""
        echo "[!] Summary:"
        echo "    PHPMyAdmin URL: $PHPMYADMIN_FQDN"
        echo "    Preselected webserver: NGINX"
        echo "    SSL: $PHPMYADMIN_SSLSTATUS"
        echo "    Email: $PHPMYADMIN_EMAIL"
        echo ""
        echo "    PHPMyAdmin SQL user"
        echo "    User: $PHPMYADMIN_USER_LOCAL"
        echo "    Password: IT WILL BE GENERATED AUTOMATICALLY"
        echo ""
    fi
}

phpmyadmin_ssl(){
    send_phpmyadmin_summary
    echo "[!] Do you want to use SSL for PHPMyAdmin? This is recommended. (Y/N)"
    read -r SSL_CONFIRM

    if [[ "$SSL_CONFIRM" =~ [Yy] ]]; then
        PHPMYADMIN_SSLSTATUS=true
        phpmyadmin_email
    fi
    if [[ "$SSL_CONFIRM" =~ [Nn] ]]; then
        PHPMYADMIN_SSLSTATUS=false
        phpmyadmin_email
    fi
}

phpmyadmin_user(){
    send_phpmyadmin_summary
    echo "[!] Please enter username for admin account."
    read -r PHPMYADMIN_USER_LOCAL
    phpmyadmin_summary
}

phpmyadmin_email(){
    send_phpmyadmin_summary
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "true" ]; then
        echo "[!] Please enter your email. It will be shared with Lets Encrypt."
        read -r PHPMYADMIN_EMAIL
        phpmyadmin_user
        fi
    if  [ "$PHPMYADMIN_SSLSTATUS" =  "false" ]; then
        phpmyadmin_user
        PHPMYADMIN_EMAIL="Unavailable"
        fi
}

### Removal of Wings ###

wings_remove(){
    echo ""
    echo "[!] Are you sure you want to remove Wings? If you have any servers on this machine, they will also get removed. (Y/N)"
    read -r UNINSTALLWINGS

    if [[ "$UNINSTALLWINGS" =~ [Yy] ]]; then
        sudo systemctl stop wings # Stops wings
        sudo rm -rf /var/lib/pterodactyl # Removes game servers and backup files
        sudo rm -rf /etc/pterodactyl  || exit || warning "Pterodactyl Wings not installed!"
        sudo rm /usr/local/bin/wings || exit || warning "Wings is not installed!" # Removes wings
        sudo rm /etc/systemd/system/wings.service # Removes wings service file
        echo ""
        echo "[!] Pterodactyl Wings has been uninstalled."
        echo ""
    fi
}

### Removal of Panel ###

uninstallpanel(){
    echo ""
    echo "[!] Do you really want to delete Pterodactyl Panel? All files & configurations will be deleted. (Y/N)"
    read -r UNINSTALLPANEL

    if [[ "$UNINSTALLPANEL" =~ [Yy] ]]; then
        uninstallpanel_backup
    fi
}

uninstallpanel_backup(){
    echo ""
    echo "[!] Do you want to keep your database and backup your .env file? (Y/N)"
    read -r UNINSTALLPANEL_CHANGE

    if [[ "$UNINSTALLPANEL_CHANGE" =~ [Yy] ]]; then
        BACKUPPANEL=true
        uninstallpanel_confirm
    fi
    if [[ "$UNINSTALLPANEL_CHANGE" =~ [Nn] ]]; then
        BACKUPPANEL=false
        uninstallpanel_confirm
    fi
}

uninstallpanel_confirm(){
    if  [ "$BACKUPPANEL" =  "true" ]; then
        mv /var/www/pterodactyl/.env .
        sudo rm -rf /var/www/pterodactyl || exit || warning "Panel is not installed!" # Removes panel files
        sudo rm /etc/systemd/system/pteroq.service # Removes pteroq service worker
        sudo unlink /etc/nginx/sites-enabled/pterodactyl.conf # Removes nginx config (if using nginx)
        sudo unlink /etc/apache2/sites-enabled/pterodactyl.conf # Removes Apache config (if using apache)
        sudo rm -rf /var/www/pterodactyl # Removing panel files
        systemctl restart nginx
        clear
        echo ""
        echo "[!] Pterodactyl Panel has been uninstalled."
        echo "    Your Panel database has not been deleted"
        echo "    and your .env file is in your current directory."
        echo ""
        fi
    if  [ "$BACKUPPANEL" =  "false" ]; then
        sudo rm -rf /var/www/pterodactyl || exit || warning "Panel is not installed!" # Removes panel files
        sudo rm /etc/systemd/system/pteroq.service # Removes pteroq service worker
        sudo unlink /etc/nginx/sites-enabled/pterodactyl.conf # Removes nginx config (if using nginx)
        sudo unlink /etc/apache2/sites-enabled/pterodactyl.conf # Removes Apache config (if using apache)
        sudo rm -rf /var/www/pterodactyl # Removing panel files
        mysql -u root -e "DROP DATABASE panel;" # Remove panel database
        systemctl restart nginx
        clear
        echo ""
        echo "[!] Pterodactyl Panel has been uninstalled."
        echo "    Files, services, configs and your database has been deleted."
        echo ""
        fi
}

### Switching Domains ###

switch(){
    if  [ "$SSLSWITCH" =  "true" ]; then
        echo ""
        echo "[!] Change domains"
        echo ""
        echo "    The script is now changing your Pterodactyl Domain."
        echo "      This may take a couple seconds for the SSL part, as SSL certificates are being generated."
        rm /etc/nginx/sites-enabled/pterodactyl.conf
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/pterodactyl-nginx-ssl.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl stop nginx
        certbot certonly --standalone -d $DOMAINSWITCH --staple-ocsp --no-eff-email -m $EMAILSWITCHDOMAINS --agree-tos || exit || warning "Errors accured."
        systemctl start nginx
        echo ""
        echo "[!] Change domains"
        echo ""
        echo "    Your domain has been switched to $DOMAINSWITCH"
        echo "    This script does not update your APP URL, you can"
        echo "    update it in /var/www/pterodactyl/.env"
        echo ""
        echo "    If using Cloudflare certifiates for your Panel, please read this:"
        echo "    The script uses Lets Encrypt to complete the change of your domain,"
        echo "    if you normally use Cloudflare Certificates,"
        echo "    you can change it manually in its config which is in the same place as before."
        echo ""
        fi
    if  [ "$SSLSWITCH" =  "false" ]; then
        echo "[!] Switching your domain.. This wont take long!"
        rm /etc/nginx/sites-enabled/pterodactyl.conf || exit || echo "An error occurred. Could not delete file." || exit
        curl -o /etc/nginx/sites-enabled/pterodactyl.conf https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/configs/pterodactyl-nginx.conf || exit || warning "Pterodactyl Panel not installed!"
        sed -i -e "s@<domain>@${DOMAINSWITCH}@g" /etc/nginx/sites-enabled/pterodactyl.conf
        systemctl restart nginx
        echo ""
        echo "[!] Change domains"
        echo ""
        echo "    Your domain has been switched to $DOMAINSWITCH"
        echo "    This script does not update your APP URL, you can"
        echo "    update it in /var/www/pterodactyl/.env"
        fi
}

switchemail(){
    echo ""
    echo "[!] Change domains"
    echo "    To install your new domain certificate to your Panel, your email address must be shared with Let's Encrypt."
    echo "    They will send you an email when your certificate is about to expire. A certificate lasts 90 days at a time and you can renew your certificates for free and easily, even with this script."
    echo ""
    echo "    When you created your certificate for your panel before, they also asked you for your email address. It's the exact same thing here, with your new domain."
    echo "    Therefore, enter your email. If you do not feel like giving your email, then the script can not continue. Press CTRL + C to exit."
    echo ""
    echo "      Please enter your email"

    read -r EMAILSWITCHDOMAINS
    switch
}

switchssl(){
    echo "[!] Select the one that describes your situation best"
    warning "   [1] I want SSL on my Panel on my new domain"
    warning "   [2] I don't want SSL on my Panel on my new domain"
    read -r option
    case $option in
        1 ) option=1
            SSLSWITCH=true
            switchemail
            ;;
        2 ) option=2
            SSLSWITCH=false
            switch
            ;;
        * ) echo ""
            echo "Please enter a valid option."
    esac
}

switchdomains(){
    echo ""
    echo "[!] Change domains"
    echo "    Please enter the domain (panel.mydomain.ltd) you want to switch to."
    read -r DOMAINSWITCH
    switchssl
}


### OS Check ###

oscheck(){
    echo "Checking your OS.."
    if  [ "$dist" =  "ubuntu" ] ||  [ "$dist" =  "debian" ]; then
        options
    else
        echo "Your OS, $dist, is not supported"
        exit 1
    fi
}

### Options ###

options(){
    echo "What would you like to do?"
    echo "[1] Install Panel."
    echo "[2] Install Wings."
    echo "[3] Install PHPMyAdmin."
    echo "[4] Remove Wings"
    echo "[5] Remove Panel"
    echo "[6] Switch Pterodactyl Domain"
    echo "Input 0-6"
    read -r option
    case $option in
        1 ) option=1
            panel
            ;;
        2 ) option=2
            wings
            ;;
        3 ) option=3
            phpmyadmin
            ;;
        4 ) option=6
            wings_remove
            ;;
        5 ) option=7
            uninstallpanel
            ;;
        6 ) option=10
            switchdomains
            ;;
        * ) echo ""
            echo "Please enter a valid option from 1-6"
    esac
}

### Start ###

clear
echo ""
echo "Pterodactyl Installer @ v2.1"
echo "Copyright 2023, dension - Silverhost.hu, <madarasz.laszlo@gmail.com>"
echo "https://github.com/dension0/Pterodactyl-Installer"
echo "based on Malthe K, <me@malthe.cc>"
echo "https://github.com/guldkage/Pterodactyl-Installer"
echo ""
echo "This script is not associated with the official Pterodactyl Panel."
echo ""
oscheck
