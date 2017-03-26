#!/bin/bash

## This script was originally developed for the Raspberry Pi. On non-Pi systems such as the
## FriendlyArm. Don't expect ports to work out of the box on non-Pi systems.
## Also, for all systems, after you load this script and before running, you need to give
## it execute permissions and sure it is saved in Linux
## format (carriage returns only) - Notepad++ has this option under edit - eol conversion.
##
## IMPORTANT:-
## 1. User PI must be in the SUDO group. Other groups added by the script.
## 2. When selection GPIO for non-Raspberry Pi devices note - specific support for ODROID C2
## 3. This script could take 3+ hours on a slow Pi Zero Wifi.... steer away from midnight to avoid any
##    updates such as dietpi upgrades etc.
## 4. For NEO (or similar) when asked by Armbian to make a new user - make it user "pi"
## 5. For Node-Red on Pi Zero,  if serial port won't connect - look at serial port permissions in /dev/
## 6. Do not access this script as SUDO.
##
## NOTE! Assuming access as pi user. Please note this script will NOT WORK AS ROOT - Must install as pi.
##
## See http://tech.scargill.net/orange-pi-pc-battle-of-the-pis/
##
## Change log
## ----------
## 25/07/2017 Tested on NanoPi M1+, host updating added and defaults on inputs added
## 18/03/2017 Tested on NanoPi M3
## 16/03/2017 Modifications to handle experimental Android Phone setup
## 10/03/2017 Modifications to detect and run with the Raspberry Pi Zero Lite (ARM6)
## 30/01/2017 Minor change to let the script work on Mint Linux on a laptop (Looks like Ubuntu)
## 14/01/2017 Updated webmin and habridge installations
## 04/01/2017 DietPi on Orange Pi Zero - installed perfectly - 1 hour. WIFI still iffy
## 26/12/2016 Complete re-hash for new menus
## 10/12/2016 Previous version tested on Pi3 with latest software Jessie
## 02/12/2016 Tested Roseapple Pi using Armbian - for Node-Red serial, had to
##            enable permissions for the serial - everything worked first time
## 16/5/2016  Tested on NanoPi M1 - (got 3 UARTS out of the M1)
## 22/06/2016 Added questions for non-Pi boards
## 22/06/2016 Tested on NanoPi NEO using Armbian Jessie Server
## 28/12/2016 Tested in DietPi and Xenial virtual machines
##            http://www.armbian.com/donate/?f=Armbian_5.20_Nanopineo_Debian_jessie_3.4.112.7z
##
## NOTE:- removed node-red-contrib-admin from Node-red setup as you can now do installs in the palette manager within the editor
## Note also  - the PHONE setting is experimental assuming an Android phone, rooted and set up with "Linux Deploy"
## as per the relevant blog entry on tech.scargill.net
##
## Typically, sitting in your home directory (/home/pi) as user Pi you might want to use NANO to install this script
## and after giving the script execute permission (sudo chmod 0744 /home/pi/script.sh)
## you could run the file as ./script.sh
##
## Includes (if you tick them:
##    Mosquitto with web sockets (Port 9001)
##    SQLITE ( xxx.xxx.xxx.xxx/phpliteadmin),
##    Node-Red (xxx.xxx.xxx:1880)
##    Node-Red-Dashboard (xxx.xxx.xxx.xxx:1880/ui)
##    Webmin (xxx.xxx.xxx:10000)
##    Apache (xxx.xxx.xxx)
## as well as web page based items like mc and /phpsysinfo
##
## Note- on the Odroid C2 everything installed except webmin. After reboot this is what I did to get it running..
##    wget http://prdownloads.sourceforge.net/webadmin/webmin_1.820_all.deb
##    sudo dpkg --install webmin_1.820_all.deb
##    That complained about missing bits so I used...
##       sudo apt-get install -y perl libnet-ssleay-perl openssl libauthen-pam-perl
##       libpam-runtime libio-pty-perl apt-show-versions python
##    That seemed to fail and suggested I use...
##       sudo apt-get -y -f install
##    That installed the lot - working - something to do with it being 64 bits - but it works -
##    pi or root user and password and https://whatever:10000
##
## http://tech.scargill.net Thanks for contributions from Aidan Ruff and Antonio Fragola. Thank you.
##
## Node-Red security added as standard - using the ADMIN login. MQTT also has same ADMIN login.
##
## ROUTINES
## Here at the beginning, a load of useful routines - see further down

# Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
startTime="$(date +%s)"
columns=$(tput cols)
user_response=""

# High Intensity
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIPurple='\e[1;95m'     # Purple
BIMagenta='\e[1;95m'    # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

skip=0
other=0


clean_stdin()
{
    while read -r -t 0; do
        read -n 256 -r -s
    done
}


# Permanent loop until both passwords are the same..
function user_input {
    local VARIABLE_NAME=${1}
    local VARIABLE_NAME_1="A"
    local VARIABLE_NAME_2="B"
    while true; do
        printf "${BICyan}$2: ${BIWhite}";
        if [ "$3" = "hide" ] ; then
            stty -echo;
        fi
        read VARIABLE_NAME_1;
        stty echo;
        if [ "$3" = "hide" ] ; then
            printf "\n${BICyan}$2 (again) : ${BIWhite}";
            stty -echo;
            read VARIABLE_NAME_2;
            stty echo;
        else
            VARIABLE_NAME_2=$VARIABLE_NAME_1;
        fi
        if [ $VARIABLE_NAME_1 != $VARIABLE_NAME_2 ] ; then
            printf "\n${BIRed}Sorry, did not match!${BIWhite}\n";
        else
            break;
        fi
    done
    readonly ${VARIABLE_NAME}=$VARIABLE_NAME_1;
    if [ "$3" == "hide" ] ; then
        printf "\n";
    fi
}


stopit=0
other=0
yes=0
nohelp=0
hideother=0

timecount(){
    sec=30
    while [ $sec -ge 0 ]; do
        if [ $nohelp -eq 1 ]; then
            
            if [ $hideother -eq 1 ]; then
                printf "${BIPurple}Continue ${BIWhite}y${BIPurple}(es)/${BIWhite}n${BIPurple}(o)/${BIWhite}a${BIPurple}(ll)/${BIWhite}e${BIPurple}(nd)-  ${BIGreen}00:0$min:$sec${BIPurple} remaining\033[0K\r${BIWhite}"
            else
                printf "${BIPurple}Continue ${BIWhite}y${BIPurple}(es)/${BIWhite}o${BIPurple}(ther)/${BIWhite}e${BIPurple}(nd)-  ${BIGreen}00:0$min:$sec${BIPurple} remaining\033[0K\r${BIWhite}"
            fi
        else
            printf "${BIPurple}Continue ${BIWhite}y${BIPurple}(es)/${BIWhite}h${BIPurple}(elp)-  ${BIGreen}00:0$min:$sec${BIPurple} remaining\033[0K\r${BIWhite}"
        fi
        sec=$((sec-1))
        trap '' 2
        stty -echo
        read -t 1 -n 1 user_response
        stty echo
        trap - 2
        if [ -n  "$user_response" ]; then
            break
        fi
    done
}


task_start(){
    printf "\r\n"
    printf "${BIGreen}%*s\n" $columns | tr ' ' -
    printf "$1"
    clean_stdin
    skip=0
    printf "\n${BIGreen}%*s${BIWhite}\n" $columns | tr ' ' -
    elapsedTime="$(($(date +%s)-startTime))"
    printf "Elapsed Time: %02d hrs %02d mins %02d secs\n" "$((elapsedTime/3600%24))" "$((elapsedTime/60%60))" "$((elapsedTime%60))"
    clean_stdin
    if [ "$user_response" != "a" ]; then
        timecount
    fi
    echo -e "                                                                        \033[0K\r"
    if  [ "$user_response" = "e" ]; then
        printf "${BIWhite}"
        exit 1
    fi
    if  [ "$user_response" = "n" ]; then
        skip=1
    fi
    if  [ "$user_response" = "o" ]; then
        other=1
    fi
    if  [ "$user_response" = "h" ]; then
        stopit=1
    fi
    if  [ "$user_response" = "y" ]; then
        yes=1
    fi
    if [ -n  "$2" ]; then
        if [ $skip -eq 0 ]; then
            printf "${BIYellow}$2${BIWhite}\n"
        else
            printf "${BICyan}%*s${BIWhite}\n" $columns '[SKIPPED]'
        fi
    fi
}


task_end(){
    printf "${BICyan}%*s${BIWhite}\n" $columns '[OK]'
}


printstatus() {
    h=$(($SECONDS/3600));
    m=$((($SECONDS/60)%60));
    s=$(($SECONDS%60));
    printf "\r\n${BIGreen}  ====\r\n  ==== ${BIYellow}$1 - ${BIGreen}Total Time: %02dh:%02dm:%02ds \r\n${BIGreen}  ====${BIWhite}\r\n"  $h $m $s;
}


############################################################################
##
## MAIN SECTION OF SCRIPT - action begins here
##
#############################################################################
##
if [[ $USER != "pi" ]]; then
    printf "\r\n${IRed}!!!! You MUST be logged in as user 'pi' with sudo privileges to continue. If \"root\", creating \"pi\" now ${IWhite}\r\n"
    if [[ $USER == "root" ]]; then
        getent passwd pi > /dev/null 2&>1
        if [ $? -eq 0 ]; then
            printf "${IRed}!!!! User \"pi\" already exists, logout as root and redo procedure as pi. ${IWhite}\r\n"
        else
            adduser --quiet --disabled-password --shell /bin/bash --home /home/pi --gecos "User" pi
            echo "pi:password" | chpasswd
            usermod pi -g sudo
            echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/pi
            chmod 0440 /etc/sudoers.d/pi
            chmod 4755 /usr/bin/sudo # bug of dietpi 145, solved in future 146: https://github.com/Fourdee/DietPi/issues/794
            printf "${IRed}!!!! User PI created, password is \"password\". Logout as root and login as pi, and redo the procedure ${IWhite}\r\n"
        fi
        exit
    else
        exit
    fi
fi

# This block done here, to prevent possible ssh timeouts...
# Allow remote root login and speed up SSH
sudo sed -i -e 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo sed -i -e 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo sed -i -e 's/TCPKeepAlive yes/TCPKeepAlive no/g' /etc/ssh/sshd_config
sudo sed -i '$ a UseDNS no' /etc/ssh/sshd_config
sudo sed -i '$ a ClientAliveInterval 30' /etc/ssh/sshd_config
sudo sed -i '$ a ClientAliveCountMax 100' /etc/ssh/sshd_config
sudo /etc/init.d/ssh restart

# Whiptail menu may already be installed by default, on the other hand maybe not.
sudo apt-get $AQUIET -y install whiptail ccze
sudo update-alternatives --set newt-palette /etc/newt/palette.original
# Another way - Xenial should come up in upper case in $DISTRO
. /etc/os-release
OPSYS=${ID^^}

if [[ $OPSYS == "LINUXMINT" ]]; then
    OPSYS="UBUNTU"
fi


if [[ $OPSYS != *"RASPBIAN"* ]] && [[ $OPSYS != *"DEBIAN"* ]] && [[ $OPSYS != *"UBUNTU"* ]] && [[ $OPSYS != *"DIETPI"* ]]; then
    printf "${BIRed}By the look of it, not one of the supported operating systems - aborting${BIWhite}\r\n"; exit
fi


# Setup a progress bar
echo "Dpkg::Progress-Fancy \"1\";" | sudo tee /etc/apt/apt.conf.d/99progressbar > /dev/null
echo "APT::Color \"1\";" | sudo tee -a /etc/apt/apt.conf.d/99progressbar > /dev/null

username="user"
userpass="password123"

adminname="admin"
adminpass="password123"

SECONDS=0

if [[ $OPSYS == *"RASPBIAN"* ]];then
    MYMENU=$(whiptail --title "Main Raspberry Pi Selection" --checklist \
        "\nSelect items for your Pi as required then hit OK" 29 73 22 \
        "quiet" "Quiet(er) install - untick for lots of info " ON \
        "prereq" "Install general pre-requisites " ON \
        "phone" "Install on Android Smartphone - see blog" OFF \
        "mosquitto" "Install Mosquitto" ON \
        "apache" "Install Apache/PHP/SQLITE + PHPLITEADMIN " ON \
        "nodejs" "Install NodeJS" ON \
        "nodered" "Install Node-Red" ON \
        "webmin" "Install Webmin" ON \
        "screen" "Install Screen" ON \
        "java" "Update Java" ON \
        "wiringpi" "Wiring Pi for the GPIO utility" OFF \
        "mpg123" "Install MPG123" ON \
        "modpass" "Mod USER and ADMIN passwords (password123)" ON \
        "phpsysinfo" "Install PHPSYSYINFO" ON \
        "upgradenpm" "Upgrade NPM to latest version " ON \
        "addindex" "Add an index page and some CSS" ON \
        "passwords" "Update ROOT and PI user passwords" OFF \
        "installcu" "Install CU for serial VT100 Terminal" ON \
        "installmc" "Install MC+MCEDIT  file manager + editor " ON \
        "installjed" "Install JED file editor" OFF \
        "habridge" "Install HA-bridge on port 82" OFF \
        "wolfram" "Remove Wolfram on a PI to save space" OFF \
        "office" "Remove LibreOffice on PI to save space" OFF 3>&1 1>&2 2>&3)
else
    MYMENU=$(whiptail --title "Main Non-Pi Selection" --checklist \
        "\nSelect items as required then hit OK" 30 74 23 \
        "quiet" "Quiet(er) install - untick for lots of info " ON \
        "prereq" "Install general pre-requisites" ON \
        "phone" "Install on Android Smartphone - see blog" OFF \
        "mosquitto" "Install Mosquitto" ON \
        "apache" "Install Apache/PHP/SQLITE + PHPLITEADMIN" ON \
        "nodejs" "Install NodeJS" ON \
        "nodered" "Install Node-Red" ON \
        "odroid" "Install ODROID C2-specific GPIO" OFF \
        "generich3" "Install GENERIC H3 GPIO (not Raspberry Pi) " OFF \
        "webmin" "Install Webmin" ON \
        "screen" "Install Screen" ON \
        "java" "Update Java" ON \
        "modpass" "Mod USER and ADMIN passwords (password123)" ON \
        "mpg123" "Install MPG123" ON \
        "opimonitor" "Install OPI-Monitor - H3 ONLY" OFF \
        "phpsysinfo" "Install PHPSYSYINFO" ON \
        "upgradenpm" "Upgrade NPN to latest version " ON \
        "addindex" "Add an index page and some CSS" ON \
        "passwords" "Update ROOT and PI user passwords" OFF \
        "installcu" "Install CU for serial VT100 Terminal" ON \
        "installmc" "Install MC+MCEDIT file manager + editor" ON \
        "installjed" "Install JED file editor" OFF \
        "habridge" "Install HA-bridge on port 82" OFF 3>&1 1>&2 2>&3)
fi

if [[ $MYMENU == *"quiet"* ]]; then
    AQUIET="-qq"
    NQUIET="-s"
fi

if [[ $MYMENU == "" ]]; then
    whiptail --title "Installation Aborted" --msgbox "Cancelled as requested." 8 78
    exit
fi

if [[ $MYMENU == *"modpass"* ]]; then
    username=$(whiptail --inputbox "Enter a user name (example user)" 8 40 $username 3>&1 1>&2 2>&3)
    if [[ -z "${username// }" ]]; then
        printf "No user name given - aborting\r\n"; exit
    fi
    
    userpass=$(whiptail --passwordbox "Enter a user password" 8 40 3>&1 1>&2 2>&3)
    if [[ -z "${userpass// }" ]]; then
        printf "No user password given - aborting${BIWhite}\r\n"; exit
    fi
    
    userpass2=$(whiptail --passwordbox "Confirm user password" 8 40 3>&1 1>&2 2>&3)
    if  [ $userpass2 == "" ]; then
        printf "${BIRed}No password confirmation given - aborting${BIWhite}\r\n"; exit
    fi
    if  [ $userpass != $userpass2 ]
    then
        printf "${BIRed}Passwords don't match - aborting${BIWhite}\r\n"; exit
    fi
    
    adminname=$(whiptail --inputbox "Enter an admin name (example admin)" 8 40 $adminname 3>&1 1>&2 2>&3)
    if [[ -z "${adminname// }" ]]; then
        printf "${BIRed}No admin name given - aborting${BIWhite}\r\n"
        exit
    fi
    
    adminpass=$(whiptail --passwordbox "Enter an admin password" 8 40 3>&1 1>&2 2>&3)
    if [[ -z "${adminpass// }" ]]; then
        printf "${BIRed}No user password given - aborting${BIWhite}\r\n"; exit
    fi
    
    adminpass2=$(whiptail --passwordbox "Confirm admin password" 8 40 3>&1 1>&2 2>&3)
    if  [ $adminpass2 == "" ]; then
        printf "${BIRed}No password confirmation given - aborting${BIWhite}\r\n"; exit
    fi
    if  [ $adminpass != $adminpass2 ]; then
        printf "${BIRed}Passwords don't match - aborting${BIWhite}\r\n"; exit
    fi
fi

if [[ $MYMENU == *"passwords"* ]]; then
    echo "Update your PI password"
    sudo passwd pi
    echo "Update your ROOT password"
    sudo passwd root
fi

if [[ $OPSYS != *"RASPBIAN"* ]]; then
    printstatus "Adding user Pi permissions"
    sudo adduser pi sudo
    sudo adduser pi adm
    sudo adduser pi dialout
    sudo adduser pi cdrom
    sudo adduser pi audio
    sudo adduser pi video
    sudo adduser pi plugdev
    sudo adduser pi games
    sudo adduser pi users
    sudo adduser pi netdev
    sudo adduser pi input
fi

if [[ $MYMENU == *"phone"* ]]; then
    echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen > /dev/null
    # echo "service rsyslog stop" | sudo tee -a /etc/init.d/rc.local > /dev/null
    sudo update-rc.d rsyslog disable
 sudo locale-gen
    sudo sed -i -e 's#exit 0##g' /etc/rc.local
    echo "cd /home/pi/habridge" | sudo tee -a /etc/rc.local > /dev/null
	echo "[ -f /home/pi/habridge/habridge-log.txt ] && rm /home/pi/habridge/habridge-log.txt" | sudo tee -a /etc/rc.local > /dev/null
    echo "nohup /usr/bin/java -jar -Dserver.port=82 -Dconfig.file=/home/pi/habridge/data/habridge.config /home/pi/habridge/ha-bridge.jar > /home/pi/habridge/habridge-log.txt 2>&1 &" | sudo tee -a /etc/rc.local > /dev/null
	echo "chmod 777 /home/pi/habridge/habridge-log.txt" | sudo tee -a /etc/rc.local > /dev/null
    echo "exit 0" | sudo tee -a /etc/rc.local > /dev/null
else
    sudo apt-get install avahi-daemon avahi-utils -y
    sudo sed -i -e 's/use-ipv6=yes/use-ipv6=no/g' /etc/avahi/avahi-daemon.conf 
fi

if [[ $MYMENU == *"wolfram"* ]]; then
    printstatus "Removing Wolfram"
    sudo apt-get $AQUIET -y purge wolfram-engine
fi

if [[ $MYMENU == *"office"* ]]; then
    printstatus "Removing LibreOffice"
    sudo apt-get $AQUIET -y remove --purge libreoffice*
fi

if [[ $MYMENU == *"prereq"* ]]; then
    printstatus "Installing pre-requisites (this could take some time)"
    sudo apt-get $AQUIET -y autoremove
    sudo apt-get $AQUIET  update
    sudo apt-get $AQUIET -y upgrade
    # Fix for RPI treating PING as a root function - by Dave
    sudo setcap cap_net_raw=ep /bin/ping
    sudo setcap cap_net_raw=ep /bin/ping6
    # Prerequisite suggested by Julian and adding in python-dev - and stuff I've added for SAMBA and telnet
    sudo apt-get install $AQUIET -y bash-completion unzip build-essential git python-serial scons libboost-filesystem-dev libboost-program-options-dev libboost-system-dev libsqlite3-dev subversion libcurl4-openssl-dev libusb-dev python-dev cmake curl samba samba-common samba-common-bin winbind telnet usbutils gawk jq
    # libboost-thread-dev libboost-all-dev
    # This line to ensure name is resolved from hosts FIRST
    sudo sed -i '/\[global\]/a name resolve order = hosts wins bcast' /etc/samba/smb.conf
fi

if [[ $MYMENU == *"jed"* ]]; then
    printstatus "Installing JED Editor"
    sudo apt-get $AQUIET -y install jed
fi

if [[ $MYMENU == *"mosquitto"* ]]; then
    printstatus "Installing Mosquitto with Websockets"
    cd
    if [[ $OPSYS == *"UBUNTU"* ]]; then
        sudo apt-get $AQUIET -y install mosquitto mosquitto-clients
    else
        wget http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key -O - | sudo apt-key add -
        echo "deb http://repo.mosquitto.org/debian jessie main" |sudo tee /etc/apt/sources.list.d/mosquitto-jessie.list
        sudo apt-get $AQUIET -y update && sudo apt-get $AQUIET -y install mosquitto mosquitto-clients
    fi
    sudo bash -c "echo -e \"listener 9001\nprotocol websockets\nlistener 1883\nallow_anonymous false\npassword_file /etc/mosquitto/passwords\" > /etc/mosquitto/conf.d/websockets.conf"
    sudo touch /etc/mosquitto/passwords
    sudo mosquitto_passwd  -b /etc/mosquitto/passwords $adminname $adminpass
fi

if [[ $MYMENU == *"wiringpi"* ]]; then
    cd
    git clone git://git.drogon.net/wiringPi
    cd ~/wiringPi
    ./build
fi

# Moved sqlite3 so that node-red sql node will install
# use back facing quotes in here - no idea why.
# Changed the order of installation of Apache etc to solve issues with ARMBIAN
#
if [[ $MYMENU == *"apache"* ]]; then
    printstatus "Installing Apache/PHP and Sqlite"
    cd
    sudo groupadd -f -g33 www-data
    
    if [[ $OPSYS != *"UBUNTU"* ]]; then
        sudo apt-get $AQUIET -y install apache2 libapache2-mod-php5 sqlite3 php5-sqlite
    else
        sudo apt-get $AQUIET -y install apache2 libapache2-mod-php7.0 sqlite3 php-sqlite3 php-xml php-mbstring
    fi
    
    cd /var/www/html
    sudo mkdir phpliteadmin
    cd phpliteadmin
    sudo wget --no-verbose --no-check-certificate http://bitbucket.org/phpliteadmin/public/downloads/phpLiteAdmin_v1-9-7-1.zip
    sudo unzip phpLiteAdmin_v1-9-7-1.zip
    sudo mv phpliteadmin.php index.php
    sudo mv phpliteadmin.config.sample.php phpliteadmin.config.php
    sudo rm *.zip
    sudo mkdir themes
    cd themes
    sudo wget --no-verbose --no-check-certificate http://bitbucket.org/phpliteadmin/public/downloads/phpliteadmin_themes_2013-12-26.zip
    sudo unzip phpliteadmin_themes_2013-12-26.zip
    sudo rm *.zip
    sudo sed -i -e 's#\$directory = \x27.\x27;#\$directory = \x27/home/pi/dbs/\x27;#g' /var/www/html/phpliteadmin/phpliteadmin.config.php
    sudo sed -i -e "s#\$password = \x27admin\x27;#\$password = \x27$adminpass\x27;#g" /var/www/html/phpliteadmin/phpliteadmin.config.php
    sudo sed -i -e "s#\$subdirectories = false;#\$subdirectories = true;#g" /var/www/html/phpliteadmin/phpliteadmin.config.php
    cd
    
    mkdir dbs
	sqlite3 /home/pi/dbs/iot.db << EOF
	CREATE TABLE IF NOT EXISTS \`pinDescription\` (
	  \`pinID\` INTEGER PRIMARY KEY NOT NULL,
	  \`pinNumber\` varchar(2) NOT NULL,
	  \`pinDescription\` varchar(255) NOT NULL
	);
	CREATE TABLE IF NOT EXISTS \`pinDirection\` (
	  \`pinID\` INTEGER PRIMARY KEY NOT NULL,
	  \`pinNumber\` varchar(2) NOT NULL,
	  \`pinDirection\` varchar(3) NOT NULL
	);
	CREATE TABLE IF NOT EXISTS \`pinStatus\` (
	  \`pinID\` INTEGER PRIMARY KEY NOT NULL,
	  \`pinNumber\` varchar(2)  NOT NULL,
	  \`pinStatus\` varchar(1) NOT NULL
	);
	CREATE TABLE IF NOT EXISTS \`users\` (
	  \`userID\` INTEGER PRIMARY KEY NOT NULL,
	  \`username\` varchar(28) NOT NULL,
	  \`password\` varchar(64) NOT NULL,
	  \`salt\` varchar(8) NOT NULL
	);
	CREATE TABLE IF NOT EXISTS \`device_list\` (
	  \`device_name\` varchar(80) NOT NULL DEFAULT '',
	  \`device_description\` varchar(80) DEFAULT NULL,
	  \`device_attribute\` varchar(80) DEFAULT NULL,
	  \`logins\` int(11) DEFAULT NULL,
	  \`creation_date\` datetime DEFAULT NULL,
	  \`last_update\` datetime DEFAULT NULL,
	  PRIMARY KEY (\`device_name\`)
	);

	CREATE TABLE IF NOT EXISTS \`readings\` (
	  \`recnum\` INTEGER PRIMARY KEY,
	  \`location\` varchar(20),
	  \`value\` int(11) NOT NULL,
	  \`logged\` timestamp not NULL DEFAULT CURRENT_TIMESTAMP ,
	  \`device_name\` varchar(40) not null,
	  \`topic\` varchar(40) not null
	);


	CREATE TABLE IF NOT EXISTS \`pins\` (
	  \`gpio0\` int(11) NOT NULL DEFAULT '0',
	  \`gpio1\` int(11) NOT NULL DEFAULT '0',
	  \`gpio2\` int(11) NOT NULL DEFAULT '0',
	  \`gpio3\` int(11) NOT NULL DEFAULT '0'
	);
	INSERT INTO PINS VALUES(0,0,0,0);
	CREATE TABLE IF NOT EXISTS \`temperature_record\` (
	  \`device_name\` varchar(64) NOT NULL,
	  \`rec_num\` INTEGER PRIMARY KEY,
	  \`temperature\` float NOT NULL,
	  \`date_time\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	CREATE TABLE IF NOT EXISTS \`Device\` (
	  \`DeviceID\` INTEGER PRIMARY KEY,
	  \`DeviceName\` TEXT NOT NULL
	);
	CREATE TABLE IF NOT EXISTS \`DeviceData\` (
	  \`DataID\` INTEGER PRIMARY KEY,
	DeviceID INTEGER,
	  \`DataName\` TEXT, FOREIGN KEY(DeviceID ) REFERENCES Device(DeviceID)
	);
	CREATE TABLE IF NOT EXISTS \`Data\` (
	SequenceID INTEGER PRIMARY KEY,
	  \`DeviceID\` INTEGER NOT NULL,
	  \`DataID\` INTEGER NOT NULL,
	  \`DataValue\` NUMERIC NOT NULL,
	  \`epoch\` NUMERIC NOT NULL,
	  \`timestamp\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP , FOREIGN KEY(DataID, DeviceID ) REFERENCES DeviceData(DAtaID, DeviceID )
	);
EOF
    
    cd
    chmod 777 /home/pi/dbs
    chmod 666 /home/pi/dbs/iot.db
    cd
fi


if [[ $MYMENU == *"nodejs"* ]]; then
    printstatus "Installing NodeJS"
    if [[ $(uname -m) == *"armv6"* ]]; then
        printstatus "Installing ARM6 version"
        wget --no-check-certificate https://nodejs.org/dist/v6.10.0/node-v6.10.0-linux-armv6l.tar.xz
        tar -xvf node-v6.10.0-linux-armv6l.tar.xz
        cd node-v6.10.0-linux-armv6l
        sudo cp -R * /usr/local/
    else
        curl -sL https://deb.nodesource.com/setup_6.x > nodesetup.sh
        sudo bash nodesetup.sh
        sudo apt-get $AQUIET -y install nodejs
    fi
fi


if [[ $MYMENU == *"nodered"* ]]; then
    #sudo npm cache clean
    printstatus "Installing Node-Red"
    sudo npm $NQUIET install -g --unsafe-perm node-red
	if [[ $MYMENU == *"phone"* ]]; then
		sudo wget -O /etc/init.d/nodered https://gist.githubusercontent.com/bigmonkeyboy/9962293/raw/0fe19671b1aef8e56cbcb20f6677173f8495e539/nodered
		sudo chmod 755 /etc/init.d/nodered && sudo update-rc.d nodered defaults
	else
		sudo wget --no-check-certificate https://raw.githubusercontent.com/node-red/raspbian-deb-package/master/resources/nodered.service -O /lib/systemd/system/nodered.service
		sudo wget --no-check-certificate https://raw.githubusercontent.com/node-red/raspbian-deb-package/master/resources/node-red-start -O /usr/bin/node-red-start
		sudo wget --no-check-certificate https://raw.githubusercontent.com/node-red/raspbian-deb-package/master/resources/node-red-stop -O /usr/bin/node-red-stop
		#sudo sed -i -e 's#=pi#=%USER#g' /lib/systemd/system/nodered.service
		sudo chmod +x /usr/bin/node-red-st*
		sudo systemctl daemon-reload
	fi

    cd # without this, you'll end up creating the .node-red folder in ~/node-v6.10.0-linux-armv6l (where you were after line 591 in case of armv6 arch)
    mkdir .node-red
    cd .node-red
    printstatus "Installing Nodes"
    npm $NQUIET install moment
    npm $NQUIET install node-red-contrib-config
    npm $NQUIET install node-red-contrib-grove
    npm $NQUIET install node-red-contrib-bigtimer
    npm $NQUIET install node-red-contrib-esplogin
    npm $NQUIET install node-red-contrib-timeout
    npm $NQUIET install node-red-node-openweathermap
    npm $NQUIET install node-red-node-google
    npm $NQUIET install node-red-node-sqlite
    npm $NQUIET install node-red-node-emoncms
    npm $NQUIET install node-red-node-geofence
    npm $NQUIET install node-red-contrib-ivona
    npm $NQUIET install node-red-contrib-moment
    npm $NQUIET install node-red-contrib-particle
    npm $NQUIET install node-red-contrib-web-worldmap
    npm $NQUIET install node-red-contrib-graphs
    npm $NQUIET install node-red-contrib-isonline
    npm $NQUIET install node-red-node-ping
    npm $NQUIET install node-red-node-random
    npm $NQUIET install node-red-node-smooth
    npm $NQUIET install node-red-contrib-npm
    npm $NQUIET install node-red-contrib-file-function
    npm $NQUIET install node-red-contrib-boolean-logic
    npm $NQUIET install node-red-node-arduino
    npm $NQUIET install node-red-contrib-blynk-websockets
    npm $NQUIET install node-red-dashboard
    npm $NQUIET install node-red-node-darksky
    npm $NQUIET install node-red-node-serialport
	npm $NQUIET install node-red-contrib-owntracks
	npm $NQUIET install node-red-contrib-chatbot
	
    sudo npm $NQUIET install bcryptjs
    
    if [[ $OPSYS == *"RASPBIAN"* ]]; then
        sudo sed -i -e 's#exit 0#chmod 777 /dev/ttyAMA0\nexit 0#g' /etc/rc.local
        sudo apt-get -y install python{,3}-rpi.gpio
        npm $NQUIET install node-red-contrib-gpio
        npm $NQUIET install raspi-io
    fi
    
    cd ~/.node-red/
    sudo service nodered start ; while [ ! -f settings.js ] ; do sudo sleep 1 ; done ; sudo service nodered stop;
    echo " "
    bcryptadminpass=$(node -e "console.log(require('bcryptjs').hashSync(process.argv[1], 8));" $adminpass)
    bcryptuserpass=$(node -e "console.log(require('bcryptjs').hashSync(process.argv[1], 8));" $userpass)
    # echo Encrypted password: $bcryptpass
    cp settings.js settings.js.bak-pre-crypt
	
	datetimestamp=`date +%Y-%m-%d_%Hh%Mm`
	cd ~/.node-red
	# This will add the TOP piece of code for non-vol variables in settings.js
	gawk -i inplace -v INPLACE_SUFFIX=-$datetimestamp '!found && /module.exports/ { print " var mySettings;\n try {\n mySettings = require(\"/home/pi/.node-red/redvars.js\");\n } catch(err) {\n mySettings = {};\n }\n"; found=1 } 1' settings.js
	
    sudo sed -i -e 's#functionGlobalContext: {#\/\/ functionGlobalContext: {#g' settings.js
    sudo sed -i -e 's#\s\s\s\s\},#    \/\/ },#g' settings.js
    sudo sed -i -e 's#^\}#,#g' settings.js
    sudo echo " " > tmpfile
    sudo echo "    httpStatic: '/home/pi/.node-red/public'," >> tmpfile
    sudo echo "    functionGlobalContext: {" >> tmpfile
    sudo echo "        os:require('os')," >> tmpfile
    sudo echo "        moment:require('moment'), " >> tmpfile
    sudo echo "        fs:require('fs'), " >> tmpfile
    sudo echo "        mySettings:mySettings " >> tmpfile
    sudo echo "    }," >> tmpfile
    sudo echo " " >> tmpfile
    sudo echo "    adminAuth: {" >> tmpfile
    sudo echo "        type: \"credentials\"," >> tmpfile
    sudo echo "        users: [{" >> tmpfile
    sudo echo "            username: \"$adminname\"," >> tmpfile
    sudo echo "            password: \"$bcryptadminpass\"," >> tmpfile
    sudo echo "            permissions: \"*\"" >> tmpfile
    sudo echo "        }]" >> tmpfile
    sudo echo "    }," >> tmpfile
    sudo echo " " >> tmpfile
    sudo echo "    httpNodeAuth: {user:\"$username\", pass:\"$bcryptuserpass\"}" >> tmpfile
    sudo echo "}" >> tmpfile
    sudo cat tmpfile >> settings.js
    sudo rm -f tmpfile
	if [[ $MYMENU == *"phone"* ]]; then
		cd && sudo mv /etc/init.d/sendsigs .
	else
		sudo systemctl enable nodered.service
	fi
fi

if [[ $OPSYS != *"RASPBIAN"* ]]; then
    
    if [[ $MYMENU == *"odroid"* ]]; then
        printstatus "Installing Odroid GPIO"
        
        git clone https://github.com/hardkernel/wiringPi.git
        cd wiringPi
        ./build
        sudo chmod a+s /usr/local/bin/gpio
    fi
    if [[ $MYMENU == *"generich3"* ]]; then
        printstatus "Installing H3 GPIO"
        # Install NanoPi H3 based IO library
        git clone https://github.com/zhaolei/WiringOP.git -b h3
        cd WiringOP
        chmod +x ./build
        sudo ./build
        cd
    fi
fi

if [[ $MYMENU == *"webmin"* ]]; then
    printstatus "Installing Webmin at port 10000 - could take some time"
    #cd
    #mkdir webmin
    #cd webmin
    #wget --no-verbose http://prdownloads.sourceforge.net/webadmin/webmin-1.831.tar.gz
    #sudo gunzip -q webmin-1.831.tar.gz
    #tar -xf webmin-1.831.tar
    #sudo rm *.tar
    #cd webmin-1.831
    #sudo ./setup.sh /usr/local/Webmin
    wget http://www.webmin.com/jcameron-key.asc -O - | sudo apt-key add -
    echo "deb http://download.webmin.com/download/repository sarge contrib" | sudo tee /etc/apt/sources.list.d/webmin.list > /dev/null
    sudo apt-get $AQUIET -y update
    sudo apt-get $AQUIET -y install webmin
    # http vs https: if you want unsecure http access on port 10000 instead of https, uncomment next line
    sudo sed -i -e 's#ssl=1#ssl=0#g' /etc/webmin/miniserv.conf
fi


if [[ $MYMENU == *"mpg123"* ]]; then
    printstatus "Installing MPG123"
    sudo apt-get $AQUIET -y install mpg123
fi

#
# This works a treat on the NanoPi NEO using H3 and Armbian - should not do any harm on other systems as it's not installed!
#
if [[ $MYMENU == *"opimonitor"* ]]; then
    printstatus "Installing Armbian Monitor"
    sudo armbianmonitor -r
fi

#task_start "Install Internet Time Updater for Webmin (NTPUpdate)?" "Installing NTPUpdate"
#if [ $skip -eq 0 ]; then
#sudo apt-get $AQUIET -y -o=Dpkg::Use-Pty=0 --force-yes install ntpdate
#task_end
#fi

#task_start "Install Email SMTP?" "Installing Email utils and SMTP..."
#if [ $skip -eq 0 ]; then
#cd
#sudo apt-get $AQUIET -y -o=Dpkg::Use-Pty=0 --force-yes install mailutils ssmtp
#task_end
#fi

if [[ $MYMENU == *"screen"* ]]; then
    printstatus "Installing Screen"
    cd
    sudo apt-get -y $AQUIET install screen
fi

if [[ $MYMENU == *"habridge"* ]]; then
    printstatus "Installing HA-Bridge on port 82"
    #sudo sed -i -e 's#80#81#g' /etc/apache2/ports.conf
    #sudo sed -i -e 's#80#81#g' /etc/apache2/sites-enabled/000-default.conf
    #sudo service apache2 restart
    ## Now to install HA-Bridge on port 82 and get it running from power up.
    cd ~
    mkdir habridge
    cd habridge
    #wget https://github.com/bwssytems/ha-bridge/releases/download/v3.5.1/ha-bridge-3.5.1.jar -O ~/habridge/ha-bridge.jar
    curl -s https://api.github.com/repos/bwssytems/ha-bridge/releases/latest | jq --raw-output '.assets[0] | .browser_download_url' | wget -i - -O ~/habridge/ha-bridge.jar
    echo -e "[Unit]\n\
Description=HA Bridge\n\
Wants=network.target\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
ExecStart=/usr/bin/java -jar -Dserver.port=82 -Dconfig.file=/home/pi/habridge/data/habridge.config /home/pi/habridge/ha-bridge.jar\n\
\n\
[Install]\n\
    WantedBy=multi-user.target\n" | sudo tee /lib/systemd/system/habridge.service
    sudo systemctl  start habridge.service
    sudo systemctl enable habridge.service
fi

if [[ $MYMENU == *"java"* ]]; then
    printstatus "Installing/Updating Java"
    echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/webupd8team-java.list
    echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" | sudo tee -a /etc/apt/sources.list.d/webupd8team-java.list
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
    sudo apt-get $AQUIET update
    echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
    sudo apt-get $AQUIET -y install oracle-java8-installer
fi

if [[ $MYMENU == *"phpsysinfo"* ]]; then
    printstatus "Installing PHPSysInfo"
    #	sudo apt-get $AQUIET -y install phpsysinfo
    #	sudo ln -s /usr/share/phpsysinfo /var/www/html
    cd /var/www/html
    sudo git clone https://github.com/phpsysinfo/phpsysinfo.git
    sudo cp /var/www/html/phpsysinfo/phpsysinfo.ini.new /var/www/html/phpsysinfo/phpsysinfo.ini
fi

# You may want to use these on a Pi or elsewhere to force either a graphical or command line environment
#sudo systemctl set-default multi-user.target
#sudo systemctl set-default graphical.target

if [[ $MYMENU == *"upgradenpm"* ]]; then
    printstatus "Upgrading NPM to the latest version"
    sudo npm $NQUIET install npm@latest -g
fi

# Add CU to enable serial VT100 mode for terminals
if [[ $MYMENU == *"installcu"* ]]; then
    printstatus "Installing CU"
    sudo apt-get $AQUIET -y install cu
fi

if [[ $MYMENU == *"installmc"* ]]; then
    printstatus "Installing MC File manager and editor"
    cd
    sudo apt-get -y $AQUIET install mc
fi

# Drop in an index file and css for a menu page
if [[ $MYMENU == *"addindex"* ]]; then
    printstatus "Adding index page and CSS"
    sudo wget $AQUIET http://www.scargill.net/iot/index.html -O /var/www/html/index.html
    sudo wget $AQUIET http://www.scargill.net/iot/reset.css -O /var/www/html/reset.css
fi

sudo apt-get $AQUIET -y clean

myip=$(hostname -I)
newhostname=$(hostname)

cd
newhostname=$(whiptail --inputbox "Nearly done. Enter new host name or OK" 8 40 $newhostname 3>&1 1>&2 2>&3)
echo $newhostname | sudo tee /etc/hostname 2&>1 /dev/null
sudo sed -i '/^127.0.1.1/ d' /etc/hosts 2&>1 /dev/null
echo 127.0.1.1 $newhostname | sudo tee -a /etc/hosts 2&>1 /dev/null
sudo /etc/init.d/hostname.sh 2&>1 /dev/null

printstatus "All done."
printf 'Current IP is %s and hostname is \r\n' "$myip" "$newhostname"
printf  "${BIMagenta}**** PLEASE REBOOT NOW ****${IWhite}\r\n"
