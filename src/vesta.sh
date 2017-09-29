#----------------------------------------------------------#
#                       Database                           #
#----------------------------------------------------------#

function check_database()
{
    local RESULT=$(mysql -sN -e "SHOW DATABASES LIKE 'admin_teamspeak'")

    if [ -z $RESULT ]; then return 0; else return 1; fi
}

function create_database()
{
    # ----------
    # Creates a mySQL database with Vesta.
    # Args:
    #     $1: password
    #
    # Return codes:
    #      0: succcess
    #      1: failed - database exsists
    # ----------
    local PASS="$1"
    if check_database; then
        /bin/bash $VESTA/bin/v-add-database admin teamspeak teamspeak $PASS
        return 0
    else
        return 1
    fi
}

function remove_database()
{
    if check_database; then
        return 1
    else
        /bin/bash $VESTA/bin/v-delete-database admin admin_teamspeak
        return 0
    fi
}

#----------------------------------------------------------#
#                      vesta.conf                          #
#----------------------------------------------------------#

function check_vesta_conf()
{
    cut -f 1 -d = $VESTA/conf/vesta.conf | grep TEAMSPEAK > /dev/null
    return $?
}

function modify_vesta_conf()
{
    if check_vesta_conf; then
        return 1
    else
        echo "TEAMSPEAK='ts3server'" >> $VESTA/conf/vesta.conf
        return 0
    fi
}

function restore_vesta_conf()
{
    if check_vesta_conf; then
        sed -i '/^TEAMSPEAK.*/d' $VESTA/conf/vesta.conf
        return 0
    else
        return 1
    fi
}

#----------------------------------------------------------#
#                     vesta binaries                       #
#----------------------------------------------------------#

function check_bin_file()
{
    local FILE="$1"
    local VALUE="$2"

    grep $VALUE $VESTA/bin/$FILE > /dev/null

    return $?
}

function modify_v_list_sys_services()
{
    check_bin_file "v-list-sys-services" "ts3extension"
    if [ $? -eq 0 ]; then
        return 1
    else
        insert_extension $VESTA/bin/v-list-sys-services \
                         src/snippet/v-list-sys-services \
                         '# Listing data'
        return 0
    fi
}

function restore_v_list_sys_services()
{
    check_bin_file "v-list-sys-services" "ts3extension"
    if [ $? -eq 0 ]; then
        remove_extension $VESTA/bin/v-list-sys-services "ts3extension"
        return 0
    else
        return 1
    fi
}

function modify_v_open_fs_config()
{
    check_bin_file "v-open-fs-config" "ts3"
    if [ $? -eq 0 ]; then
        return 1
    else
        sed -i 's/my.cnf/ts3|my.cnf/' $VESTA/bin/v-open-fs-config
        return 0
    fi
}

function restore_v_open_fs_config()
{
    check_bin_file "v-open-fs-config" "ts3"
    if [ $? -eq 0 ]; then
        sed -i 's/ts3|//' $VESTA/bin/v-open-fs-config
        return 0
    else
        return 1
    fi
}

#----------------------------------------------------------#
#                       Firewall                           #
#----------------------------------------------------------#

function get_firewall_rule()
{
    # ----------
    # Check that a port rule exists in the firewall
    # Args:
    #     $1: value
    #
    # Return variables:
    #     $2: rule number
    #
    # Return status:
    #     1: Rule does not exist
    # ----------
    local VALUE="$1"
    local RESULT=$(/bin/bash $VESTA/bin/v-list-firewall \
                    | grep ${VALUE} \
                    | awk '{$1=$1};1' \
                    | cut -f 1 -d' ')

    if [ ! -z $RESULT ]; then
        eval $2="${RESULT}"
        return 0
    else
        return 1
    fi
}

function remove_firewall_rules()
{
    get_firewall_rule "9987" RULE
    if [ $? == 0 ]; then /bin/bash $VESTA/bin/v-delete-firewall-rule $RULE; fi

    get_firewall_rule "10011,30033" RULE
    if [ $? == 0 ]; then /bin/bash $VESTA/bin/v-delete-firewall-rule $RULE; fi
}

function add_firewall_rules()
{
    remove_firewall_rules

    /bin/bash $VESTA/bin/v-add-firewall-rule accept 0.0.0.0/0 9987 udp teamspeak3
    /bin/bash $VESTA/bin/v-add-firewall-rule accept 0.0.0.0/0 10011,30033 tcp teamspeak3
}
