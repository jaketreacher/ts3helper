#!/bin/bash

#----------------------------------------------------------#
#                         Help                             #
#----------------------------------------------------------#

function show_help()
{
    echo "usage: sudo $(basename $0)"
    echo
    echo "TeamSpeak 3 Helper: Installer"
    echo "Downloads and installs TeamSpeak 3 and injects Vesta enhancements."
    echo
    echo "optional arguments:"
    printf "  %-20s  %s\n"  "--help" "Display this message."
}

#----------------------------------------------------------#
#                      Functions                           #
#----------------------------------------------------------#

. src/utils.sh
. src/file_ext_helper.sh
. src/vesta.sh

#----------------------------------------------------------#
#                 Variables & Verifications                #
#----------------------------------------------------------#

# Setup variables
TS3_ARCHIVE="/tmp/teamspeak.tar.bz2"
TS3_DIR="/usr/local/teamspeak"

# Help requested
if value_in_array "--help" "$@"; then show_help; exit; fi

# curl
if [ ! -e '/usr/bin/curl' ]; then echo "curl not installed."; exit; fi

# wget
if [ ! -e '/usr/bin/wget' ]; then echo "wget not installed."; exit; fi

# check user "teamspeak" doesn't exist
cut -f 1 -d : /etc/passwd | grep "^teamspeak$" > /dev/null
if [ $? == 0 ]; then
    echo "The user 'teamspeak' already exists."
    exit
fi

# Check directory doesn't exist
if [ -e $TS3_DIR ]; then echo "'${TS3_DIR}' already exists. Exiting."; exit; fi

# check vesta configured
if [ -e '/usr/local/vesta' ] && [ "$VESTA" != "/usr/local/vesta" ]; then
    echo "VESTA not configured properly. Try restarting."
    exit
fi

# sudo
if [ $(whoami) != "root" ]; then echo "Permission denied."; exit; fi

#----------------------------------------------------------#
#                       Action                             #
#----------------------------------------------------------#

# Download ts3server
if [ ! -e $TS3_ARCHIVE ]; then
    download_teamspeak server_linux_amd64 || { echo "Download failed."; exit 1; }
else
    echo "Using previously downloaded archive."
fi

# Extract and move files
echo "Creating directory."
mkdir -p $TS3_DIR

echo "Extracting files."
tar xC $TS3_DIR -f $TS3_ARCHIVE --strip-components=1

# Configure 
if [ -e '/usr/bin/mysql' ] && [ -e "$VESTA" ]; then
    echo "=== Using Vesta-enhanced configurations ==="

    PASSWORD=$(generate_password 10)

    create_database $PASSWORD \
        && echo "Database created." \
        || echo "Database exists."

    cp $TS3_DIR/redist/libmariadb.so.2 $TS3_DIR/
    cp src/init.d/ts3server /etc/init.d/ts3server

    cp src/teamspeak/ts3db.ini $TS3_DIR/
    cp src/teamspeak/ts3server.ini $TS3_DIR/

    sed -i "s/{username}/admin_teamspeak/" $TS3_DIR/ts3db.ini
    sed -i "s/{database}/admin_teamspeak/" $TS3_DIR/ts3db.ini
    sed -i "s/{password}/${PASSWORD}/" $TS3_DIR/ts3db.ini
    
    # Add service to vesta.conf
    modify_vesta_conf \
        && echo "vesta.conf: added configuration." \
        || echo "vesta.conf: already modified."

    # Edit v-list-sys-services
    modify_v_list_sys_services \
        && echo "v-list-sys-services: added configuration." \
        || echo "v-list-sys-services: already modified."

    # Edit v-open-fs-config
    modify_v_open_fs_config \
        && echo "v-open-fs-config: added configuration." \
        || echo "v-open-fs-config: already modified."

    # Copy custom html pages
    echo "Copying web files."
    cp src/vesta/edit_server_ts3server.html $VESTA/web/templates/admin/
    cp -R src/vesta/ts3server $VESTA/web/edit/server/

    # Configure firewall
    add_firewall_rules && echo "Configured firewall rules."

    START_OPTIONS='inifile=ts3server.ini'
else
    echo "=== Using basic configurations ==="
    cp src/init.d/ts3server-nosql /etc/init.d/ts3server
fi

# User and permissions
useradd -r -s /bin/false -c 'TeamSpeak Daemon' -d /nonexistent teamspeak \
    && echo "TeamSpeak daemon created."
chown -R teamspeak:teamspeak $TS3_DIR \
    && echo "Directory permissions configured."

# Save privilege key
echo "Starting manually to obtain privilege key."
sudo -u teamspeak $TS3_DIR/ts3server_startscript.sh start $START_OPTIONS &> /dev/null
wait_for_service ts3server && sleep 5
$TS3_DIR/ts3server_startscript.sh stop &> /dev/null
grep -oP 'token=.*' $TS3_DIR/logs/* | cut -f 2 -d = > $TS3_DIR/privilegekey.txt
echo "Key: $(cat /usr/local/teamspeak/privilegekey.txt)"
echo "Key saved in '${TS3_DIR}/privilegekey.txt'."

# Start service
echo "Starting service."
update-rc.d ts3server defaults &> /dev/null
service ts3server start &> /dev/null

echo "Installation complete."
