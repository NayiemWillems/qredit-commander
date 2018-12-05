#!/bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                     #
#                                                     #
#               Qredit Commander Script               #
#               Qredits to the ARK TEAM               #
#                                                     #
#                                                     #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#


### Adding some color ###

# Line coloring functions

function red {
        echo -e "$(tput bold; tput setaf 1)$1$(tput sgr0)"
}

function igreen {
		echo -e "$(tput bold; tput setaf 0; tput setab 2)$1$(tput sgr0)"
}

function ired {
		echo -e "$(tput bold; tput setaf 3; tput setab 1)$1$(tput sgr0)"
}

function green {
        echo -e "$(tput bold; tput setaf 2)$1$(tput sgr0)"
}

function yellow {
        echo -e "$(tput bold; tput setaf 3)$1$(tput sgr0)"
}
function orange {
		echo -e "$(tput bold; tput setaf 5; tput setab 3)$1$(tput sgr0)"
}


### Checking if the script is started as root ###

if [ "$(id -u)" = "0" ]; then
	clear
	echo -e "\n$(ired " !!! This script should NOT be started using sudo or as the root user !!! ") "
	echo -e "\nUse $(green "bash qredit-dev-commander.sh") as a REGULAR user instead"
	echo -e "Execute ONCE $(green "chmod +x qredit-dev-commander.sh") followed by $(green "ENTER")"
	echo -e "and start it only by $(green "./qredit-dev-commander.sh") as regular user after\n"
	exit 1
fi

### Checking the Virtualization Environment ###

if [ $(systemd-detect-virt -c) != "none" ]; then
	clear
	echo "$(ired "                                                                                 ")"
	echo "$(ired "                    OpenVZ / LXC / Virtuoso Container detected!                  ")"
	echo "$(ired "                                                                                 ")"
	echo "$(ired "    Running Qredit Node on a Container based virtual system is not recommended   ")"
	echo "$(ired "   Please change your VPS provider with one that uses hardware Virtualization.   ")"
	echo "$(ired "                                                                                 ")"
	echo "$(ired "                            This script will now exit!                           ")"
	echo "$(ired "                                                                                 ")"
	exit 1
fi


# TEMP N
# sudo apt-get install npm
# sudo npm install -g n
# sudo n 6.9.2


# ----------------------------------
# Variables
# ----------------------------------

EDIT=nano

GIT_ORIGIN=master

LOC_SERVER="http://localhost:5101"

ADDRESS=""

SNAPDIR="$HOME/dev-snapshots"

re='^[0-9]+$' # For numeric checks

#pubkey="02a3e3e5fc36565ab4275ddfee1592667f6c46f5e9aa7528499511d65c5e82a7db"

# Logfile
log="install_qreditdev.log"

#~ SEED NODES ~#
seed0=("http://213.125.22.45:5101" "seed01")

#~ API CALL ~#
apicall="/api/loader/status/sync"

# ----------------------------------
# Arrays
# ----------------------------------

# Install prereq packages array
declare -a array=("postgresql" "postgresql-contrib" "libpq-dev" "build-essential" "python" "git" "curl" "jq" "libtool" "autoconf" "locales" "automake" "locate" "wget" "zip" "unzip" "htop" "nmon" "iftop")

#~ Network height checker ~#
#declare -a nodes=(seed0[@])
declare -a nodes=(seed0[@])
declare -a height=()

# Get array length
arraylength=${#nodes[@]}

# ----------------------------------
# Functions
# ----------------------------------

# ASCII Art function
function asciiart {
clear
tput bold; tput setaf 1
cat << "EOF"

 ___________ ___________ _____ _____  
|  _  | ___ \  ___|  _  \_   _|_   _| 
| | | | |_/ / |__ | | | | | |   | |   
| | | |    /|  __|| | | | | |   | |   
\ \/' / |\ \| |___| |/ / _| |_  | |   
 \_/\_\_| \_\____/|___/  \___/  \_/                            
______ _____ _   _ _   _  _____ _____ 
|  _  \  ___| | | | \ | ||  ___|_   _|
| | | | |__ | | | |  \| || |__   | |  
| | | |  __|| | | | . ` ||  __|  | |  
| |/ /| |___\ \_/ / |\  || |___  | |  
|___/ \____/ \___/\_| \_/\____/  \_/                                                                   

EOF
tput sgr0
}

pause(){
        read -p "$(yellow "       Press [Enter] key to continue...")" fakeEnterKey
}

# Current Network Height

function net_height {
	# Spawning curl netheight processes loop
        for n in {1..$arraylength..$arraylength}; do
                for (( i=1; i<${arraylength}+1; i++ )); do
                        saddr=${!nodes[i-1]:0:1}
                        echo $i $(curl -m 3 -s $saddr$apicall | cut -f 5 -d ":" | sed 's/,.*//' | sed 's/}$//') >> $HOME/tout.txt &
                done
                wait
        done

	# Array read
	while read ind line; do
		height[$ind]=$line # assign array values
	done < $HOME/tout.txt
	rm $HOME/tout.txt

	# Finding the highest seednodes block
	IFS=$'\n'
	highest=($(sort -nr <<<"${height[*]}"))
	unset IFS
}

# Find parent PID
function top_level_parent_pid {
        # Look up the parent of the given PID.
        pid=${1:-$$}
	if [ "$pid" != "0" ]; then
	        stat=($(</proc/${pid}/stat))
        	ppid=${stat[3]}

	        # /sbin/init always has a PID of 1, so if you reach that, the current PID is
        	# the top-level parent. Otherwise, keep looking.
	        if [[ ${ppid} -eq 1 ]] ; then
        	        echo ${pid}
        	else
                	top_level_parent_pid ${ppid}
        	fi
	else
		pid=0
	fi
}

# Process management variables
function proc_vars {
        node=`pgrep -a "node" | grep qredit-dev-node | awk '{print $1}'`
        if [ "$node" == "" ] ; then
                node=0
        fi

        # Is Postgres running
        pgres=`pgrep -a "postgres" | awk '{print $1}'`

        # Find if forever process manager is runing
        frvr=`pgrep -a "node" | grep forever | awk '{print $1}'`

        # Find the top level process of node
        top_lvl=$(top_level_parent_pid $node)

        # Looking for qredit-node installations and performing actions
        qreditdir=`locate -b qredit-dev-node`

        # Getting the parent of the install path
        parent=`dirname $qreditdir 2>&1`

        # Forever Process ID
        forever_process=`forever --plain list | grep $node | sed -nr 's/.*\[(.*)\].*/\1/p'`

        # Node process work directory
        nwd=`pwdx $node 2>/dev/null | awk '{print $2}'`
}

#PSQL Queries
query() {
PUBKEY="$(psql -d qredit_dev -t -c 'SELECT ENCODE("publicKey",'"'"'hex'"'"') as "publicKey" FROM mem_accounts WHERE "address" = '"'"$ADDRESS"'"' ;' | xargs)"
DNAME="$(psql -d qredit_dev -t -c 'SELECT username FROM mem_accounts WHERE "address" = '"'"$ADDRESS"'"' ;' | xargs)"
PROD_BLOCKS="$(psql -d qredit_dev -t -c 'SELECT producedblocks FROM mem_accounts WHERE "address" = '"'"$ADDRESS"'"' ;' | xargs)"
MISS_BLOCKS="$(psql -d qredit_dev -t -c 'SELECT missedblocks FROM mem_accounts WHERE "address" = '"'"$ADDRESS"'"' ;' | xargs)"
#BALANCE="$(psql -d qredit_dev -t -c 'SELECT (balance/100000000.0) as balance FROM mem_accounts WHERE "address" = '"'"$ADDRESS"'"' ;' | sed -e 's/^[[:space:]]*//')"
BALANCE="$(psql -d qredit_dev -t -c 'SELECT to_char(("balance"/100000000.0), '"'FM 999,999,999,990D00000000'"' ) as balance FROM mem_accounts WHERE "address" = '"'"$ADDRESS"'"' ;' | xargs)"
HEIGHT="$(psql -d qredit_dev -t -c 'SELECT height FROM blocks ORDER BY HEIGHT DESC LIMIT 1;' | xargs)"
RANK="$(psql -d qredit_dev -t -c 'WITH RANK AS (SELECT DISTINCT "publicKey", "vote", "round", row_number() over (order by "vote" desc nulls last) as "rownum" FROM mem_delegates where "round" = (select max("round") from mem_delegates) ORDER BY "vote" DESC) SELECT "rownum" FROM RANK WHERE "publicKey" = '"'0369093c456fd8704ae4e401f3b3a3ad1581453cf7feb34c513a2f599f9adf6aac'"';' | xargs)"
}

# Stats Address Change
change_address() {
	echo "$(yellow "   Enter your delegate address for Stats")"
	echo "$(yellow "    WITHOUT QUOTES, followed by 'ENTER'")"
	read -e -r -p "$(yellow " :") " inaddress
	while [ ! "${inaddress:0:1}" == "Q" ] ; do
		echo -e "\n$(ired "   Enter delegate ADDRESS, NOT the SECRET!")\n"
		read -e -r -p "$(yellow " :") " inaddress
	done
	ADDRESS=$inaddress
#	sed -i "s#\(.*ADDRESS\=\)\( .*\)#\1 "\"$inaddress\""#" $DIR/$BASH_SOURCE
	sed -i "1,/\(.*ADDRESS\=\)/s#\(.*ADDRESS\=\)\(.*\)#\1"\"$inaddress\""#" $DIR/$BASH_SOURCE
}


# Forging Turn
turn() {
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#	echo $DIR
#	echo "$BASH_SOURCE"
#	echo "$ADDRESS"
	if [ "$ADDRESS" == "" ] ; then
		change_address
#		echo "$(yellow "   Enter your delegate address for Stats")"
#		echo "$(yellow "    WITHOUT QUOTES, followed by 'ENTER'")"
#		read -e -r -p "$(yellow " :") " inaddress
#		while [ ! "${inaddress:0:1}" == "A" ] ; do
#			echo -e "\n$(ired "   Enter delegate ADDRESS, NOT the SECRET!")\n"
#			read -e -r -p "$(yellow " :") " inaddress
#		done
#		ADDRESS=$inaddress
##		sed -i "s#\(.*ADDRESS\=\)\( .*\)#\1 "\"$inaddress\""#" $DIR/$BASH_SOURCE
#		sed -i "1,/\(.*ADDRESS\=\)/s#\(.*ADDRESS\=\)\(.*\)#\1"\"$inaddress\""#" $DIR/$BASH_SOURCE
	fi
#	pause
while true; do
#	trap : INT
	query
	net_height
	asciiart
	proc_vars
	queue=`curl --connect-timeout 3 -f -s $LOC_SERVER/api/delegates/getNextForgers?limit=51 | jq ".delegates"`
	is_forging=`curl -s --connect-timeout 1 $LOC_SERVER/api/delegates/forging/status?publicKey=$PUBKEY 2>/dev/null | jq ".enabled"`
	is_syncing=`curl -s --connect-timeout 1 $LOC_SERVER/api/loader/status/sync 2>/dev/null | jq ".syncing"`
	pos=0
	for position in $queue
	do
		position=`echo "$position" | tr -d '",'`
		if [[ $PUBKEY == $position ]]; then
#			echo "$position : $pos <=="
			turn=$pos
		fi
		pos=`expr $pos + 1`
	done
	git_upd_check
	echo -e "$(yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")"
	echo -e "$(green "                   NODE STATS")"
	echo -e "$(yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")"
	echo
	echo -e "$(green "      Delegate         : ")$(yellow "$DNAME")"
	echo -e "$(green "      Forging          : ")$(yellow "$is_forging")"
	echo -e "$(green "      Current Rank     : ")$(yellow "$RANK")"
	echo -e "$(green "      Forging Position : ")$(yellow "$turn")"
	echo -e "$(green "      Node Blockheight : ")$(yellow "$HEIGHT")"
	echo -e "$(green "      Net Height       : ")$(yellow "$highest")"
#	echo -e "$(green "Public Key:")\n$(yellow "$PUBKEY")\n"
	echo -e "$(green "      Forged Blocks    : ")$(yellow "$PROD_BLOCKS")"
	echo -e "$(green "      Missed Blocks    : ")$(yellow "$MISS_BLOCKS")"
	echo -e "$(green "      Qredit Balance   : ")$(yellow "$BALANCE")"
	echo
	echo -e "\n$(yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")"
        if [ -e $qreditdir/app.js ]; then
                echo -e "\n$(green "       ✔ Qredit Dev Node installation found!")\n"
                if [ "$node" != "" ] && [ "$node" != "0" ]; then
                        echo -e "$(green "      Qredit Dev Node process is running with:")"
                        echo -e "$(green "   System PID: $node, Forever PID $forever_process")"
                        echo -e "$(green "   and Work Directory: $qreditdir")\n"
                else
                        echo -e "\n$(red "       ✘ No Qredit Dev Node process is running")\n"
                fi
        else
                echo -e "\n$(red "       ✘ No Qredit Dev Node installation is found")\n"
        fi
	echo -e "\n$(yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")"
	echo -e "\n$(yellow "          Press 'Enter' to terminate          ")"
	read -t 4 && break

#sleep 4
done
}

# Stats Display
function stats {
	asciiart
	proc_vars
	is_forging=`curl -s --connect-timeout 1 $LOC_SERVER/api/delegates/forging/status?publicKey=$pubkey 2>/dev/null | jq ".enabled"`
	is_syncing=`curl -s --connect-timeout 1 $LOC_SERVER/api/loader/status/sync 2>/dev/null | jq ".syncing"`

	if [ "$node" != "" ] && [ "$node" != "0" ]; then
		echo -e "$(green "       Instance of Qredit Dev Node found with:")"
		echo -e "$(green "       System PID: $node, Forever PID $forever_process")"
		echo -e "$(green "       Directory: $qreditdir")\n"
	else
		echo -e "\n$(red "       ✘ Qredit Dev Node process is not running")\n"
		pause
	fi

}

# Updating the locate database
function db_up {
	echo -e "$(red "Please enter your sudo password for user $USER")"
	sudo updatedb
}

# Update and upgrade the OS
function os_up {
	asciiart
	echo -e "$(yellow "        Checking for system updates...")\n"
	sudo apt-get update >&- 2>&- #-yqq 2>/dev/null
	avail_upd=`/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 1`
	sec_upd=`/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 2`
		if [ "$avail_upd" == 0 ]; then
		        echo -e "$(green "        There are no updates available")\n"
		        sleep 1
		else
			echo -e "\n$(red "        There are $avail_upd updates available")"
			echo -e "$(red "        $sec_upd of them are security updates")"
			echo -e "\n$(yellow "            Updating the system...")"
			sudo apt-get upgrade -yqq >&- 2>&- #2>/dev/null
			sudo apt-get dist-upgrade -yq >&- 2>&- #2>/dev/null
			#sudo apt-get purge nodejs postgresql postgresql-contrib samba*
			sudo apt-get autoremove -yyq >&- 2>&- #2>/dev/null
			sudo apt-get autoclean -yq >&- 2>&- #2>/dev/null
			echo -e "\n$(green "          ✔ The system was updated!")"
			echo -e "\n$(red "        System restart is recommended!\n")"
		fi
}

# Install prerequisites
function prereq {
	# Get array length
        arraylength=${#array[@]}

        # Installation loop
        echo -e "$(yellow "-----------------------------------------------")"
        for (( i=1; i<${arraylength}+1; i++ ));
		do
			asciiart;
          		echo -e "$(yellow "         Installing prerequisites...") "
          		echo -e "$(yellow "-----------------------------------------------")" # added
               		echo -e "$(yellow "  $i  /  ${arraylength}  :  ${array[$i-1]}")"
			if [ $(dpkg-query -W -f='${Status}' ${array[$i-1]} 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
                        	sudo apt-get install -yqq >&- 2>&- ${array[$i-1]};
                	else
                        	echo "$(green " Package: ${array[$i-1]} is already installed!")"
                	fi
                	echo -e "$(yellow "-----------------------------------------------")"
		        sleep 0.5
		        clear
		done
}

# Install and set locale
function set_locale {
        # Checking Locale first
        asciiart
        if [ `locale -a | grep ^en_US.UTF-8` ] || [ `locale -a | grep ^en_US.utf8` ] ; then
                echo -e "$(green "     ✔  Locale en_US.UTF-8 is installed")\n"
                echo -e "$(yellow "  Checking if the locale is set in bashrc...")"
                        if `grep -E "(en_US.UTF-8)" $HOME/.bashrc` ; then
                                echo -e "\n$(green "          ✔ bashrc is already set")"
                        else
                                # Setting the bashrc locale
                                echo -e "$(red " ✘ Not set yet. Setting the bashrc locale...")"
                                echo -e "export LC_ALL=en_US.UTF-8" >> $HOME/.bashrc
                                echo -e "export LANG=en_US.UTF-8" >> $HOME/.bashrc
                                echo -e "export LANGUAGE=en_US.UTF-8" >> $HOME/.bashrc
                                echo -e "$(green "           ✔ bashrc locale was set")\n"

                                # Setting the current shell locale
                                echo -e "$(yellow "      Setting current shell locale...")\n"
                                export LC_ALL=en_US.UTF-8
                                export LANG=en_US.UTF-8
                                export LANGUAGE=en_US.UTF-8
                                echo -e "$(green "           ✔ Shell locale was set")"
                        fi
        else
                # Install en_US.UTF-8 Locale
                echo -e "$(red "   ✘ Locale en_US.UTF-8 is not installed")\n"
                echo -e "$(yellow "   Generating locale en_US.UTF-8...")"
                sudo locale-gen en_US.UTF-8
                sudo update-locale LANG=en_US.UTF-8
                echo -e "$(green "    ✔  Locale generated successfully.")\n"

                # Setting the current shell locale
                echo -e "$(yellow "     Setting current shell locale...")\n"
                export LC_ALL=en_US.UTF-8
                export LANG=en_US.UTF-8
                export LANGUAGE=en_US.UTF-8
                echo -e "$(green "         ✔ Shell locale was set")\n"

                # Setting the bashrc locale
                echo -e "$(yellow "   Setting the bashrc locale...")\n"
                echo "export LC_ALL=en_US.UTF-8" >> $HOME/.bashrc
                echo "export LANG=en_US.UTF-8" >> $HOME/.bashrc
                echo "export LANGUAGE=en_US.UTF-8" >> $HOME/.bashrc
                echo -e "$(green "        ✔ bashrc locale was set")"
        fi
}

# Install and set NTP
function ntpd {
        # Check if ve are running in a OpenVZ or LXC Container for NTP Install
        if [ $(systemd-detect-virt) == "lxc" ] || [ $(systemd-detect-virt) == "openvz" ]; then
                echo -e "Your host is running in LXC or OpenVZ container. NTP is not required. \n"
        else
                echo -e "Checking if NTP is running first... \n"
                if ! sudo pgrep -x "ntpd" > /dev/null; then
                        echo -e "No NTP found. Installing... "
                        sudo apt-get install ntp -yyq &>> $log
                        sudo service ntp stop &>> $log
                        sudo ntpd -gq &>> $log
			sleep 2
                        sudo service ntp start &>> $log
			sleep 2
                                if ! sudo pgrep -x "ntpd" > /dev/null; then
                                        echo -e "NTP failed to start! It should be installed and running for Qredit.\n Check /etc/ntp.conf for any issues and correct them first! \n Exiting."
                                        exit 1
                                fi
                        echo -e "NTP was successfuly installed and started with PID:" `sudo pgrep -x "ntpd"`
                else
                        echo "NTP is up and running with PID:" `sudo pgrep -x "ntpd"`
                fi
        fi
        echo "-------------------------------------------------------------------"
}

# Logrotate for Qredit Dev Node logs
function log_rotate {
	if [[ "$(uname)" == "Linux" ]]; then

		if [ ! -f /etc/ .d/qredit-dev-logrotate ]; then
			echo -e " Setting up Logrotate for Qredit dev node log files."
			sudo bash -c "cat << 'EOF' >> /etc/logrotate.d/qredit-dev-logrotate
$HOME/$qreditdir/logs/qreditdev.log {
        size=50M
        copytruncate
        create 660 $USER $USER
        missingok
        notifempty
        compress
        delaycompress
        daily
        rotate 7
        dateext
        maxage 7
}
EOF"
		else
			echo -e "$(green "      ✔ Logrotate file already exists!")\n"
		fi
	fi
}

# GIT Update Check
function git_upd_check {

	if [ -d "$qreditdir" ]; then

		cd $qreditdir

		git remote update >&- 2>&-
		UPSTREAM=${1:-'@{u}'}
		LOCAL=$(git rev-parse @)
		REMOTE=$(git rev-parse "$UPSTREAM")
		BASE=$(git merge-base @ "$UPSTREAM")

		cd $HOME

		if [ "$LOCAL" == "$REMOTE" ]; then
			echo -e "         $(igreen "    QreditDevNode is Up-to-date    \n")"
			UP_TO_DATE=1
		elif [ "$LOCAL" == "$BASE" ]; then
			echo -e "         $(ired "   Please Update! Press (3)    \n")"
			UP_TO_DATE=0
		else
			echo -e "         $(ired "           Diverged            \n")"
		fi
	fi

}

# Install PostgreSQL
function inst_pgdb {
        sudo apt install -yyq postgresql postgresql-contrib >&- 2>&-
}

# Purge the Postgres Database
function purge_pgdb {
        if [ $(dpkg-query -W -f='${Status}' postgresql } 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
                echo "$(green "  Postgres is not installed, nothing to purge. Exiting.") "
        else
	echo -e "    $(ired "                                        ")"
	echo -e "    $(ired "   WARNING! This option will stop all   ")"
	echo -e "    $(ired "   running Qredit Dev Node processes and will  ")"
	echo -e "    $(ired "   remove the databases and PostgreSQL  ")"
	echo -e "    $(ired "   installation! Are you REALLY sure?   ")"
	echo -e "    $(ired "                                        ")"
	read -e -r -p "$(yellow "\n    Type (Y) to proceed or (N) to cancel: ")" -i "N" YN
		if [[ "$YN" =~ [Yy]$ ]]; then
			echo -e "$(yellow "\n     Proceeding with PostgreSQL removal... \n")"
			forever --silent --plain stopall
			sleep 1
			drop_db
			drop_user

        		# stop the DB if running first...
		        sudo service postgresql stop
		        sleep 1
		        sudo apt --purge remove -yq postgresql\* >&- 2>&-
		        sudo rm -rf /etc/postgresql/ >&- 2>&-
		        sudo rm -rf /etc/postgresql-common/ >&- 2>&-
		        sudo rm -rf /var/lib/postgresql/ >&- 2>&-
		        sudo userdel -r postgres >&- 2>&-
		        sudo groupdel postgres >&- 2>&-
			echo -e "$(yellow "\n          PostgreSQL has been removed\n")"

			read -e -r -p "$(yellow "\n  Proceed with PostgreSQL installation (Y/n): ")" -i "Y" YN
			if [[ "$YN" =~ [Yy]$ ]]; then
				echo -e "$(yellow "\n   Proceeding with PostgreSQL installation... \n")"
				inst_pgdb
				create_db
				echo -e "$(yellow "\n    PostgreSQL has been installed and set.\n")"
				pause
			fi
		fi
        fi
}

function snap_menu {
if [ ! -d "$SNAPDIR" ]; then
	mkdir -p $SNAPDIR
fi

if [ "$(ls -A $SNAPDIR)" ]; then
	if [[ $(expr `date +%s` - `stat -c %Y $SNAPDIR/current`) -gt 900 ]]; then
		echo -e "$(yellow " Existing Current snapshot is older than 15 minutes")"
        	read -e -r -p "$(yellow "\n Download from qredit.cloud? (Y) or use Local (N) ")" -i "Y" YN
			if [[ "$YN" =~ [Yy]$ ]]; then
				echo -e "$(yellow "\n     Downloading latest snapshot from qredit.cloud\n")"
				rm $SNAPDIR/current
				wget -nv https://snapshots.qredit.cloud/dev/current -O $SNAPDIR/current
				echo -e "$(yellow "\n              Download finished\n")"
			fi
	fi

        snapshots=( $(ls -t $SNAPDIR | xargs -0) )
        echo -e "$(yellow "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")"
        echo -e "$(green "           List of local snapshots:")"
        echo -e "$(yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")"
        for (( i=0; i<${#snapshots[*]}; i++ )); do
                if [ $i -le 9 ]; then
                        echo "             "  $(($i+1)): ${snapshots[$i]}
                else
                        echo "            "  $(($i+1)): ${snapshots[$i]}
                fi
        done

        read -ep "$(yellow "\n       Which snapshot to be restored? ")"
        if [[ "${REPLY}" =~ $re ]]; then
        ## Numeric checks
                if [ $REPLY -le ${#snapshots[*]} ]; then
                        echo -e "$(yellow "\n         Restoring snapshot ${snapshots[$((REPLY-1))]}")\n"
			pg_restore -O -j 8 -d qredit_db $SNAPDIR/${snapshots[$(($REPLY-1))]} 2>/dev/null
			echo -e "$(green "   Snapshot ${snapshots[$(($REPLY-1))]} was restored sucessfuly")\n"
                else
                        echo -e "$(red "\n        Value is out of list range!\n")"
			snap_menu
                fi
        else
                echo -e "$(red "\n             $REPLY is not a number!\n")"
		snap_menu
        fi
else
        echo -e "$(red "    No snapshots found in $SNAPDIR")"
        read -e -r -p "$(yellow "\n Do you like to download the latest snapshot? (Y/n) ")" -i "Y" YN
        if [[ "$YN" =~ [Yy]$ ]]; then
		echo -e "$(yellow "\n     Downloading current snapshot from qredit.cloud\n")"
                wget -nv https://snapshots.qredit.cloud/dev/current  -O $SNAPDIR/current
		echo -e "$(yellow "\n              Download finished\n")"
        fi

        if [[ $? -eq 0 ]]; then
                read -e -r -p "$(yellow "  Do you like to restore the snapshot now? (Y/n) ")" -i "Y" YN
                        if [[ "$YN" =~ [Yy]$ ]]; then
                                #here calling the db_restore function
				echo -e "$(yellow "\n   Restoring $SNAPDIR/current ... ")"
                                pg_restore -O -j 8 -d qredit_db $SNAPDIR/current 2>/dev/null
				echo -e "$(green "\n    Current snapshot has been restored\n")"
                        fi
        else
                echo -e "$(red "\n    Error while retriving the snapshot")"
                echo -e "$(red "  Please check that the file exists on server")"
        fi

fi
}

# Check if program is installed
function node_check {
        # defaulting to 1
        return_=1
        # changing to 0 if not found
        type $1 >/dev/null 2>&1 || { return_=0; }
        # return value
        # echo "$return_"
}

# Install NVM and node
function nvm {
        node_check node
        if [ "$return_" == 0 ]; then
                echo -e "$(red "      ✘ Node is not installed, installing...")"
                curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.32.0/install.sh 2>/dev/null | bash >>install.log
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
                ### Installing node ###
                nvm install 6.9.5 >>install.log
                nvm use 6.9.5 >>install.log
                nvm alias default 6.9.5 >>install.log
                echo -e "$(green "      ✔ Node `node -v` has been installed")"
        else
                echo -e "$(green "      ✔ Node `node -v` is  alredy installed")"
        fi

        node_check npm
        if [ "$return_" == 0 ]; then
                echo -e "$(red "      ✘ NPM is not installed, installing...")"
                ### Install npm ###
                npm install -g npm >>install.log 2>&1
                echo -e "$(green "      ✔ NPM `npm -v` has been installed")"
        else
                echo -e "$(green "      ✔ NPM `npm -v` is alredy installed")"
        fi

        node_check forever
        if [ "$return_" == 0 ]; then
                echo -e "$(red "      ✘ Forever is not installed, installing...")"
                ### Install forever ###
                npm install forever -g >>install.log 2>&1
                echo -e "$(green "      ✔ Forever has been installed")"
        else
                echo -e "$(green "      ✔ Forever is already installed")"
        fi

        # Setting fs.notify.max_user_watches
        if grep -qi 'fs.inotify' /etc/sysctl.conf ; then
                echo -e "\n$(green "  fs.inotify.max_user_watches is already set")"
        else
                echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
        fi

        echo -e "\n$(yellow "Check install.log for reported install errors")"
}

# Install Qredit Dev Node
function inst_qredit {
#	proc_vars
	cd $HOME
        mkdir qredit-dev-node
        git clone https://github.com/NayiemWillems/qredit-dev-node.git 2>/dev/null
        cd qredit-dev-node
	git checkout $GIT_ORIGIN 2>/dev/null
	git pull origin $GIT_ORIGIN 2>/dev/null
        npm install grunt-cli -g 2>/dev/null
        npm install libpq 2>/dev/null
        npm install secp256k1 2>/dev/null
        npm install bindings 2>/dev/null
        git submodule init 2>/dev/null
        git submodule update 2>/dev/null
        npm install 2>/dev/null
}

# Create Qredit Dev user and DB
function create_db {
        #check if PG is running here if not Start.
        if [ -z "$pgres" ]; then
                sudo service postgresql start
        fi
        sleep 1
#       sudo -u postgres dropdb --if-exists qredit_db
#       sleep 1
#       sudo -u postgres dropuser --if-exists $USER # 2>&1
#       sleep 1
	sudo -u postgres psql -c "update pg_database set encoding = 6, datcollate = 'en_US.UTF8', datctype = 'en_US.UTF8' where datname = 'template0';" >&- 2>&-
	sudo -u postgres psql -c "update pg_database set encoding = 6, datcollate = 'en_US.UTF8', datctype = 'en_US.UTF8' where datname = 'template1';" >&- 2>&-
        sudo -u postgres psql -c "CREATE USER $USER WITH PASSWORD 'password' CREATEDB;" >&- 2>&-
        sleep 1
        createdb qredit_dev
}

# Check if DB exists
function db_exists {
        # check if it's running and start if not.
        if [ -z "$pgres" ]; then
                sudo service postgresql start
        fi

        if [[ ! $(sudo -u postgres psql qredit_dev -c '\q' 2>&1) ]]; then
                read -r -n 1 -p "$(yellow "  Database exists! Do you want to drop it? (y/n):") " YN
                        if [[ "$YN" =~ [Yy]$ ]]; then
                                drop_db;
                        fi
        else
                echo "Database not exist."
        fi
}

# Check if User exists
function user_exists {
        # check if it's running and start if not.
        if [ -z "$pgres" ]; then
                sudo service postgresql start
        fi

        if [[ $(sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$USER'" 2>&1) ]]; then
                echo "User $USER exists";
                read -r -n 1 -p "$(yellow "  User $USER exists! Do you want to remove it? (y/n):") " YN

                        if [[ "$YN" =~ [Yy]$ ]]; then
                                sudo -u postgres dropuser --if-exists $USER
                        fi
        else
                echo "User $USER does not exist"
        fi
}

# Drop QREDIT DEV DB
function drop_db {
        # check if it's running and start if not.
        if [ -z "$pgres" ]; then
                sudo service postgresql start
        fi
        dropdb --if-exists qredit_dev
}

function drop_user {
        if [ -z "$pgres" ]; then
                sudo service postgresql start
        fi

        if [[ $(sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$USER'" 2>&1) ]]; then
		sudo -u postgres dropuser --if-exists $USER
        else
                echo "DB User $USER does not exist"
        fi
}

function update_qreditdev {
	if [ "$UP_TO_DATE" -ne 1 ]; then
	        cd $qreditdir
#       	 forever stop app.js
#		TMP_PASS=$(jq -r '.forging.secret | @csv' config.$GIT_ORIGIN.json)
		TMP_PASS=$(jq -r '.forging.secret | @csv' config.json)
		mv config.json ../
	        git pull origin $GIT_ORIGIN
		git checkout $GIT_ORIGIN
	        npm install
		sleep 1

#		if [ ! -e config.$GIT_ORIGIN.json ]; then
#			mv ../config.$GIT_ORIGIN.json .
#		else
#			jq -r '.forging.secret = ['"$TMP_PASS"']' config.$GIT_ORIGIN.json > config.$GIT_ORIGIN.tmp && mv config.$GIT_ORIGIN.tmp config.$GIT_ORIGIN.json
#		fi
		if [ ! -e config.json ]; then
			mv ../config.json .
		else
			jq -r '.forging.secret = ['"$TMP_PASS"']' config.json > config.tmp && mv config.tmp config.json
		fi

		unset TMP_PASS
#		forever restart $forever_process
#	        forever start app.js --genesis genesisBlock.json --config config.json
	else
		echo "Qredit Dev Node is already up to date!"
		sleep 2
	fi
}

# Put the password in config.json
function secret {
        echo -e "\n"
	#Put check if qreditdir is empty, if it is stays only config.json
	echo -e "$(yellow " Enter (copy/paste) your private key (secret)")"
	echo -e "$(yellow "    (WITHOUT QUOTES!) followed by 'Enter'")"
        read -e -r -p ": " secret
#        sed -i "s/\"secret\":\ \[/& \"$secret\"\ /" $qreditdir/config.json
	sed -i "/.*secret.*/c\ \ \ \ \"secret\":\ \[\ \"$secret\"\ \]\," $qreditdir/config.json
}

### Menu Options ###

# Install QREDIT DEV node
one(){
	cd $HOME
	proc_vars
	if [ -e $qreditdir/app.js ]; then
		clear
		asciiart
		echo -e "\n$(green "       ✔ Qredit Dev Node is already installed!")\n"
		if [ "$node" != "" ] && [ "$node" != "0" ]; then
                	echo -e "$(green "A working instance of Qredit Dev Node is found with:")"
                	echo -e "$(green "System PID: $node, Forever PID $forever_process")"
        	        echo -e "$(green "and Work Directory: $qreditdir")\n"
                fi
		pause
	else
		clear
		asciiart
		echo -e "$(yellow "           Installing Qredit Dev node....")"
		create_db
		inst_qredit
		clear
		asciiart
		echo -e "$(green "          ✔ Qredit node was installed")\n"
		sudo updatedb
		sleep 1
		proc_vars
		log_rotate
		config="$parent/config.json"
#		echo "$config" 2>/dev/null
#		pause
		if  [ ! -e $config ] ; then
			read -e -r -p "$(yellow " Do you want to set your Secret Key now? (Y/N): ")" -i "Y" keys
			if [ "$keys" == "Y" ]; then
				five
			fi
		fi
	fi
}

# Reinstall Qredit Dev Node
two(){
	clear
	asciiart
	echo -e "$(ired "!!! This option will erase your DB and Qredit Dev Node installation !!!")\n"
	read -e -r -p "$(red "   Are you sure that you want to proceed? (Y/N): ")" -i "N" keys
	if [ "$keys" == "Y" ]; then
		proc_vars
        	if [ -e $qreditdir/app.js ]; then
                	clear
                	asciiart
                	echo -e "\n$(green " ✔ Qredit Dev Node installation found in $qreditdir")\n"
                	if [ "$node" != "" ] && [ "$node" != "0" ]; then
                        	echo -e "$(green "A working instance of Qredit Dev Node is found with:")"
                        	echo -e "$(green "System PID: $node, Forever PID $forever_process")"
				echo -e "$(yellow "           Stopping Qredit Dev node ...")\n"
				cd $qreditdir
				forever --plain stop $forever_process >&- 2>&-
				cd $parent
                	fi
			echo -e "$(yellow "    Backing up configuration file to $parent")\n"
			sleep 1
			if [ -e $parent/config.json ] ; then
				read -e -r -p "$(yellow "    Backup file exists! Overwrite? (Y/N): ")" -i "Y" keys
				if [ "$keys" == "Y" ]; then
					cp $qreditdir/config.json $parent
					cd $parent
				fi
			else
				cp $qreditdir/config.json $parent
				cd $parent
			fi
			echo -e "$(yellow "        Removing Qredit Dev Node directory...")\n"
			sleep 1
			rm -rf $qreditdir
			drop_db
			drop_user
			one
			echo ""
			if [ -e $parent/config.json ] ; then
				read -e -r -p "$(yellow " Do you want to restore your config? (Y/N): ")" -i "Y" keys
#				echo "Break1"; pause
				if [ "$keys" == "Y" ]; then
					cp $parent/config.json $qreditdir
					echo -e "\n$(green " ✔ Config was restored in $qreditdir")\n"
					read -e -r -p "$(yellow " Do you want to start Qredit Dev Node now? (Y/N): ")" -i "Y" keys
					if [ "$keys" == "Y" ]; then
						start
					fi
				else
					read -e -r -p "$(yellow " Do you want to start Qredit Dev Node now? (Y/N): ")" -i "Y" keys
					if [ "$keys" == "Y" ]; then
						start
					fi
				fi
			fi
		else
			echo -e "\n$(green "    ✔ Previous installation not found.")\n"
			drop_db
			drop_user
			sleep 1
			one
			proc_vars
			if [ -e $parent/config.json ] ; then
				read -e -r -p "$(yellow " Do you want to restore your config? (Y/N): ")" -i "Y" keys
				if [ "$keys" == "Y" ]; then
					cp $parent/config.json $qreditdir
					echo -e "\n$(green " ✔ Config was restored in $qreditdir")\n"
				fi
			else
				echo -e "\n$(yellow " No backup config was found in $parent")\n"
				read -e -r -p "$(yellow " Do you want to set your Secret Key now? (Y/N): ")" -i "Y" keys
				if [ "$keys" == "Y" ]; then
					secret
				fi
			fi
#			echo "Break2"; pause
			read -e -r -p "$(yellow " Do you want to start Qredit Dev Node now? (Y/N): ")" -i "Y" keys
			if [ "$keys" == "Y" ]; then
				start
			fi
		fi
	fi
}

three(){
        asciiart
        proc_vars
	if [ "$UP_TO_DATE" -ne 1 ]; then
	        if [ "$node" != "" ] && [ "$node" != "0" ]; then
        	        echo -e "$(green "       Instance of Qredit Dev Node found with:")"
                	echo -e "$(green "       System PID: $node, Forever PID $forever_process")"
	                echo -e "$(green "       Directory: $qreditdir")\n"
			echo -e "\n$(green "             Updating Qredit Dev Node...")\n"
			update_qredit
	                echo -e "$(green "                Restarting...")"
        	        forever restart $forever_process >&- 2>&-
                	echo -e "\n$(green "    ✔ Qredit Node was successfully restarted")\n"
	                pause
		else
                	echo -e "\n$(red "       ✘ Qredit Dev Node process is not running")\n"
			echo -e "$(green "            Updating Qredit Dev Node...")\n"
			update_qredit
			forever start app.js --genesis genesisBlock.json --config config.json >&- 2>&-
			echo -e "$(green "    ✔ Qredit Dev Node was successfully started")\n"
        	        pause
        	fi
	else
			echo -e "         $(igreen " Qredit Dev Node is already Up-to-date \n")"
			sleep 2
	fi

}

four(){
        asciiart
        proc_vars
        if [ "$node" != "" ] && [ "$node" != "0" ]; then
                echo -e "$(green "       Instance of Qredit Dev Node found with:")"
                echo -e "$(green "       System PID: $node, Forever PID $forever_process")"
                echo -e "$(green "       Directory: $testdir")\n"
                echo -e "\n$(green "            Stopping Qredit Dev Node...")\n"
		cd $qreditdir
		forever stop $forever_process >&- 2>&-
		echo -e "$(green "             Dropping QREDIT DEV DB...")\n"
                drop_db
		drop_user
		echo -e "$(green "             Creating QREDIT DEV DB...")\n"
		create_db

		# Here should come the snap choice
		snap_menu
                echo -e "$(green "            Starting QREDIT DEV Node...")"
		forever start app.js --genesis genesisBlock.json --config config.json >&- 2>&-
                echo -e "\n$(green "    ✔ Qredit Dev Node was successfully started")\n"
                pause
        else
                echo -e "\n$(red "       ✘ Qredit Dev Node process is not running")\n"
                echo -e "$(green "             Dropping Qredit Dev DB...")\n"
		drop_db
		drop_user
		echo -e "$(green "             Creating Qredit Dev DB...")\n"
		create_db

		# Here should come the snap choice
		snap_menu
		echo -e "$(green "            Starting Qredit Dev Node...")"
		cd $qreditdir
                forever start app.js --genesis genesisBlock.json --config config.json >&- 2>&-
                echo -e "$(green "    ✔ Qredit Dev Node was successfully started")\n"
                pause
        fi
}

five(){
	clear
	asciiart
	proc_vars
	secret
	echo -e "\n$(green "      ✔  Secret has been set/replaced")\n"
	read -e -r -p "$(yellow " Do you want to apply your new config? (Y/N): ")" -i "Y" keys
	if [ "$keys" == "Y" ]; then
        	if [ "$node" != "" ] && [ "$node" != "0" ]; then
			echo -e "\n$(green "       Instance of Qredit Dev Node found with:")"
			echo -e "$(green "       System PID: $node, Forever PID $forever_process")"
			echo -e "$(green "       Directory: $qreditdir")\n"
			echo -e "$(green "                Restarting...")"
	                forever restart $forever_process >&- 2>&-
			echo -e "\n$(green "    ✔ Qredit Dev Node was successfully restarted")\n"
			pause
		else
			echo -e "\n$(red "       ✘ Qredit Dev Node process is not running")\n"
			echo -e "$(green "            Starting Qredit Dev Node...")\n"
			forever start app.js --genesis genesisBlock.json --config config.json >&- 2>&-
			echo -e "$(green "    ✔ Qredit Dev Node was successfully started")\n"
			pause
		fi
	fi
}

# OS Update
six(){
os_up
pause
}

# Additional Options
seven(){
#nano
while true
do
        asciiart
# HERE COMES THE GITHUB CHECK
        git_upd_check
        sub_menu
        read_sub_options
done

sub_menu
##turn
#pause
}

# Create Snapshot
eight(){
QreditNetwork="dev"
QreditNodeDirectory="$HOME/qredit-dev-node"
SnapshotDirectory="$HOME/dev-snapshots"

### Test qredit-dev-node Started
clear
	asciiart
			echo -e "\n$(green "    Please HODL. This is going to take a while.")\n"	

QreditNodePid=$( pgrep -a "node" | grep qredit-dev-node | awk '{print $1}' )
if [ "$QreditNodePid" != "" ] ; then

    ### Delete Snapshot(s) older then 6 hours
    find $SnapshotDirectory -name "qredit_$QreditNetwork_*" -type f -mmin +360 -delete

    ### Write SeedNodeFile
    QreditNodeConfig="$QreditNodeDirectory/config.json"
    SeedNodeFile='/tmp/qredit_seednode'
    echo '' > $SeedNodeFile
    cat $QreditNodeConfig | jq -c -r '.peers.list[]' | while read Line; do
        SeedNodeAddress="$( echo $Line | jq -r '.ip' ):$( echo $Line | jq -r '.port' )"
        echo "$SeedNodeAddress" >>  "$SeedNodeFile"
    done

    ### Load SeedNodeFile in Memory & Remove SeedNodeFile
    declare -a SeedNodeList=()
    while read Line; do
        SeedNodeList+=($Line)
    done < $SeedNodeFile
    rm -f $SeedNodeFile

    ### Get highest Height from 5 random seed nodes
    SeedNodeCount=${#SeedNodeList[@]}
    for (( TopHeight=0, i=1; i<=5; i++ )); do
        RandomOffset=$(( RANDOM % $SeedNodeCount ))
        SeedNodeUri="http://${SeedNodeList[$RandomOffset]}/api/loader/status/sync"
        SeedNodeHeight=$( curl --max-time 2 -s $SeedNodeUri | jq -r '.height' )
        if [ "$SeedNodeHeight" -gt "$TopHeight" ]; then TopHeight=$SeedNodeHeight; fi
    done

    ### Get local qredit-dev-node height
    LocalHeight=$( curl --max-time 2 -s 'http://127.0.0.1:5101/api/loader/status/sync' | jq '.height' )

    ### Test qredit-node Sync.
    if [ "$LocalHeight" -eq "$TopHeight" ]; then


        ForeverPid=$( forever --plain list | grep $QreditNodePid | sed -nr 's/.*\[(.*)\].*/\1/p' )
        cd $QreditNodeDirectory

        ### Stop qredit-dev-node
        forever --plain stop $ForeverPid > /dev/null 2>&1 &
        sleep 1

        ### Dump Database
        SnapshotFilename='qredit_'$QreditNetwork'_'$LocalHeight
        pg_dump -O "qredit_$QreditNetwork" -Fc -Z6 > "$SnapshotDirectory/$SnapshotFilename"
        sleep 1

        ### Start qredit-dev-node
        forever --plain start app.js --genesis "genesisBlock.json" --config "config.json" > /dev/null 2>&1 &

        ### Update Symbolic Link
        rm -f "$SnapshotDirectory/current"
        ln -s "$SnapshotDirectory/$SnapshotFilename" "$SnapshotDirectory/current"


        	if [ "$node" != "" ] && [ "$node" != "0" ]; then
	                forever restart $forever_process >&- 2>&-
			echo -e "\n$(green "    ✔ Qredit Dev snapshot was successfully created")\n"
			pause
    fi
fi
     
fi 
}

# Start Qredit Dev Node
start(){
        proc_vars
	echo $qreditdir
        if [ -e $qreditdir/app.js ]; then
                clear
                asciiart
                echo -e "\n$(green "       ✔ Qredit Dev Node installation found!")\n"
                if [ "$node" != "" ] && [ "$node" != "0" ]; then
                        echo -e "$(green " A working instance of Qredit Dev Node was found with:")"
                        echo -e "$(green "   System PID: $node, Forever PID $forever_process")"
                        echo -e "$(green "   and Work Directory: $qreditdir")\n"
		else
			echo -e "$(green "            Starting Qredit Dev Node...")\n"
			cd $qreditdir
			forever start app.js --genesis genesisBlock.json --config config.json >&- 2>&-
			cd $parent
			echo -e "$(green "    ✔ Qredit Dev Node was successfully started")\n"
			sleep 1
			proc_vars
			echo -e "\n$(green "       Qredit Dev Node started with:")"
			echo -e "$(green "   System PID: $node, Forever PID $forever_process")"
			echo -e "$(green "   and Work Directory: $qreditdir")\n"
                fi
	else
		echo -e "\n$(red "       ✘ No Qredit Dev Node installation is found")\n"
	fi
pause
}

# Node Status
status(){
        proc_vars
        if [ -e $qreditdir/app.js ]; then
                clear
                asciiart
                echo -e "\n$(green "       ✔ Qredit Dev Node installation found!")\n"
                if [ "$node" != "" ] && [ "$node" != "0" ]; then
                        echo -e "$(green "      Qredit Dev Node process is working with:")"
                        echo -e "$(green "   System PID: $node, Forever PID $forever_process")"
                        echo -e "$(green "   and Work Directory: $qreditdir")\n"
                else
                        echo -e "\n$(red "       ✘ No Qredit Dev Node process is running")\n"
                fi
        else
                echo -e "\n$(red "       ✘ No Qredit Dev Node installation is found")\n"
        fi
pause
}

restart(){
	asciiart
	proc_vars
	if [ "$node" != "" ] && [ "$node" != "0" ]; then
                echo -e "$(green "       Instance of Qredit Dev Node found with:")"
                echo -e "$(green "       System PID: $node, Forever PID $forever_process")"
                echo -e "$(green "       Directory: $qreditdir")\n"
		echo -e "$(green "                Restarting...")"
		forever restart $forever_process >&- 2>&-
		echo -e "\n$(green "    ✔ Qredit Dev Node was successfully restarted")\n"
		pause
	else
		echo -e "\n$(red "       ✘ Qredit Dev Node process is not running")\n"
		pause
	fi
}

# Stop Node
killit(){
        proc_vars
        if [ -e $qreditdir/app.js ]; then
                clear
                asciiart
                echo -e "\n$(green "       ✔ Qredit Dev Node installation found!")\n"
                if [ "$node" != "" ] && [ "$node" != "0" ]; then
                        echo -e "$(green " A working instance of Qredit Dev Node was found with:")"
                        echo -e "$(green "   System PID: $node, Forever PID $forever_process")"
                        echo -e "$(green "   and Work Directory: $testdir")\n"
			echo -e "$(green "            Stopping Qredit Dev Node...")\n"
			cd $testdir
			forever stop $forever_process >&- 2>&-
			cd $parent
			echo -e "$(green "    ✔ Qredit Dev Node was successfully stopped")\n"
                else
			echo -e "\n$(red "       ✘ No Qredit Dev Node process is running")\n"
                fi
        else
                echo -e "\n$(red "       ✘ No Qredit Dev Node installation is found")\n"
        fi
pause
}


# Logs
log(){
	clear
	echo -e "\n$(yellow " Use Ctrl+C to return to menu")\n"
	proc_vars
	trap : INT
	tail -f $qreditdir/logs/qreditdev.log
#pause
}

subfive(){
        clear
	asciiart
	purge_pgdb

}

subsix(){
        clear
        asciiart
        change_address

}



# Menu
show_menus() {
    tput bold; tput setaf 3
    echo "         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "                  O P T I O N S"
    echo "         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo
    echo "              1. Install Qredit Dev"
    echo "              2. Reinstall Qredit Dev"
    echo "              3. Update Qredit Dev"
    echo "              4. Rebuild Database"
    echo "              5. Set/Reset Secret"
    echo "              6. OS Update"
    echo "              7. Additional options"
    echo "              8. Create Snapshot"
    echo
    echo "         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo
    echo "              Q. Qredit Dev Start"
    echo "              R. Restart Qredit Dev"
    echo "              T. Kill Qredit Dev"
    echo "              S. Node Status"
        echo "              L. Node Log"
    echo "              0. Exit"
    echo
    tput sgr0
}

# Sub Menu
sub_menu() {
    tput bold; tput setaf 3
    echo "         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "               Additional Options"
    echo "         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo
    echo "           1. Install Qredit Dev Cli"
    echo "           2. Install Qredit Dev Explorer"
    echo "           3. Install Snapshot script"
    echo "           4. Install Restart script"
    echo "           5. Purge PostgeSQL"
    echo "           6. Replace Delegate Address"
    echo "           0. Exit to Main Manu"
    echo
    echo "         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo
    tput sgr0
}

read_options(){
    local choice
    read -p "        Enter choice [1 - 8,Q,R,T,S,L]: " choice
    case $choice in
        1) one ;;
        2) two ;;
        3) three ;;
        4) four ;;
        5) five ;;
        6) six ;;
        7) seven ;;
        8) eight ;;
        Q) start ;;
        R) restart ;;
        T) killit;;
        [sS]) turn;;
        [lL]) log;;
        0) exit 0;;
        *) echo -e "$(red "             Incorrect option!")" && sleep 1
    esac
}


read_sub_options(){
    local choice1
    read -p "          Enter choice [1 - 7]: " choice1
    case $choice1 in
        1) subone ;;
        2) subtwo ;;
        3) subthree ;;
        4) four ;;
        5) subfive ;;
        6) subsix ;;
        7) seven ;;
        0) break ;;
        *) echo -e "$(red "             Incorrect option!")" && sleep 1
    esac
}






read_sub_options(){
	local choice1
	read -p "          Enter choice [1 - 7]: " choice1
	case $choice1 in
		1) subone ;;
		2) subtwo ;;
		3) subthree ;;
		4) four ;;
		5) subfive ;;
		6) subsix ;;
		7) seven ;;
		0) init ;;
		*) echo -e "$(red "             Incorrect option!")" && sleep 1
	esac
}






# ----------------------------------------------
# Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP


# ----------------------------------------------
# First Run Initial OS update and prerequisites
# ----------------------------------------------
if [ -e ./.firstrun ] ; then
	sdate=$(date +"%Y%m%d")
	fdate=$(date +"%Y%m%d")
else
	fdate=$(date -r ./.firstrun +"%Y%m%d")
fi

if [ -e ./.firstrun ] && [ "$fdate" <  "$sdate" ]; then
#       if [ -e ./.firstrun ] && [ $(date -r ./.firstrun +"%Y%m%d") <  $(date +"%Y%m%d") ]; then
                echo -e "$(yellow "      Checking for system updates...")\n"
                os_up
		log_rotate
                touch ./.firstrun
fi

if [ -e ./.firstrun ] && [ "$fdate" =  "$sdate" ]; then
	clear
	asciiart
	echo -e "$(green "         ✔ Your system is up to date.")\n"
else
	if [ ! -e ./.firstrun ] ; then
		clear
		asciiart
		db_up
		clear
		asciiart
		######echo ""
		echo -e "$(yellow "It's the first time you are starting this script!") "
		echo -e "$(yellow "First it will check if your system is up to date") "
		echo -e "$(yellow "install updates and needed prerequisites")\n"
		echo -e "$(yellow "Please HODL! It can take up to 5 minutes!")\n"
		pause
		os_up
		clear
		asciiart
		sleep 1
		node_check iftop
		        if [ "$return_" == 0 ]; then
				echo -e "$(yellow "         Installing prerequisites...") "
				prereq
			else
				echo -e "$(green "    ✔ Prerequisites are already installed")"
			fi
		clear
		asciiart
		echo -e "$(yellow "        Setting up NTP and Locale...") "
		sleep 1
		echo ""
		ntpd
		echo ""
		set_locale
		clear
		asciiart
		echo -e "$(yellow "       Setting up NodeJS environment...") "
		sleep 1
		nvm
		sleep 5
		touch ./.firstrun
		echo -e "\n$(ired "    !!!  PLEASE REBOOT YOUR SYSTEM NOW  !!!    ") "
		  echo -e "$(ired "    !!!   START THIS SCRIPT AGAIN AND   !!!    ") "
		  echo -e "$(ired "    !!!  CHOOSE '1' TO INSTALL Qredit NODE !!!    ") "
		exit
	fi
fi

sudo updatedb
proc_vars
#exit

init() {
    # ----------------------------------------------
    # Menu infinite loop
    # ----------------------------------------------

    while true
    do
        asciiart
        # HERE COMES THE GITHUB CHECK
        git_upd_check
        show_menus
        read_options
    done
}

# ----------------------------------------------
# Init Application
# ----------------------------------------------

init
