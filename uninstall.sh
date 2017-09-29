#!/bin/bash

#----------------------------------------------------------#
#                         Help                             #
#----------------------------------------------------------#

function show_help()
{
    echo "usage: sudo $(basename $0)"
    echo
    echo "TeamSpeak 3 Helper: Uninstaller"
    echo "Uninstalls TeamSpeak 3 and removes Vesta enchancements."
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
TS3_DIR="/usr/local/teamspeak"

# Help requested
if value_in_array "--help" "$@"; then show_help; exit; fi

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

echo "Removing startup service."
service ts3server stop &> /dev/null
rm /etc/init.d/ts3server &> /dev/null
update-rc.d ts3server remove &> /dev/null

if [ -e '/usr/bin/mysql' ] && [ -e "$VESTA" ]; then
    remove_database \
        && echo "Database: removed." \
        || echo "Database: unchanged."

    restore_vesta_conf \
        && echo "vesta.conf: restored." \
        || echo "vesta.conf: unchanged."

    restore_v_list_sys_services \
        && echo "v-list-sys-services: restored." \
        || echo "v-list-sys-services: unchanged."

    restore_v_open_fs_config \
        && echo "v-open-fs-config: restored." \
        || echo "v-open-fs-config: unchanged."

    remove_firewall_rules && echo "Firewall updated."
fi

deluser teamspeak &> /dev/null \
    && echo "Daemon: deleted." \
    || echo "Daemon: does not exist."
if [ -e $TS3_DIR ]; then
    rm -rf $TS3_DIR && echo "Teamspeak Directory: deleted."
else
    echo "Teamspeak Directory: does not exist."
fi

echo "Uninstallation complete."
