#!/bin/bash

function get_latest()
{
    # ----------
    # Get the latest version of TeamSpeak
    # Args:
    #     $1: type
    #
    # Return variables:
    #     $2: download link
    #
    # Return status:
    #     1: Unable to find link matching the type specified
    # ----------
    OLD_IFS=$IFS
    IFS=$'\n'

    local SITE="https://www.teamspeak.com/en/downloads"
    local DL_TYPE="$1"

    printf 'Fetching site...'
    local INFO="$(wget -qO- $SITE | tr '\n' ' ' | awk '$1=$1')"
    echo ' done.'

    printf 'Scraping content...'
    local SECTIONS=($(echo $INFO \
        | grep -oP '<div class="file.*?</h3> \K.*?(?=\<div class="task)' \
        | grep -oP '.*?(?=<i class.*</div?)')
    )

    local DLS=()
    for SECTION in ${SECTIONS[@]}; do
        DLS+=($(echo $SECTION | grep -oP 'href="\K.*?(?=")'))
    done

    local idx=0
    for DL in ${DLS[@]}; do
        if [[ $DL == *"${DL_TYPE}"* ]]; then
            break
        fi
        ((idx++))
    done
    echo ' done.' # scraping content

    # If the idx exceeds the number of downloads, it means that
    # the TYPE was not found.
    if [[ $idx -ge ${#DLS[@]} ]]; then
        echo 'Download not found.'
        return 1
    fi

    eval $2="${DLS[${idx}]}"

    IFS=$OLD_IFS
}

function download_teamspeak()
{
    # ----------
    # Download a specific type of teamspeak
    # Args:
    #     $1: the type of file to download
    #
    # Return:
    #     1: Unable to find file matching type specified
    # ----------
    local TYPE=$1
    local DL_LINK

    echo "Fetching download link"
    get_latest $TYPE DL_LINK || exit 1

    if [ -z $DL_LINK ]; then
        return 1
    fi

    echo ${DL_LINK}
    curl -o $TS3_ARCHIVE $DL_LINK
}

function wait_for_service()
{
    # ----------
    # Wait for the specified service to start.
    # Polling every 1 second
    #
    # Args:
    #     $1: the service to wait for
    # ----------
    local SERVICE="$1"
    while true; do
        pidof ${SERVICE} > /dev/null && break || sleep 1
    done

    return 0
}

function generate_password()
{
    # ----------
    # Generate a random string. Matrix consits of 0-9 A-Z a-z.
    # Args:
    #     $1: length
    # ----------
    local matrix='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    local length="$1"
    local idx=1
    while [ $idx -le $length ]; do
        local pass="$pass${matrix:$(($RANDOM%${#matrix})):1}"
        let idx+=1
    done

    echo "$pass"
}

function value_in_array()
{
    # ----------
    # Check if a value is present in an array
    # Args:
    #     $1: value
    #     $2+: array values
    #
    # Return:
    #     0 if found, 1 if not
    # ----------
    local value=$1; shift

    for item; do
        if [[ $item == $value ]]; then
            return 0
        fi
    done
    return 1
}
