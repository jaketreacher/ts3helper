function insert_extension()
{
    # ----------
    # Insert an 'extension' into a file
    # Args:
    #     $1: FILE to edit
    #     $2: file with EXTension contents
    #     $3: the TAG to insert the extension before
    # ----------
    local FILE="$1"
    local EXT="$2"
    local TAG="$3"

    local LINE=$(grep -noP "^${TAG}" ${FILE} | cut -f 1 -d :)
    local TOP=$(cat ${FILE} | head -n $((${LINE} - 1)))
    local BOT=$(cat ${FILE} | tail -n +$LINE)

    local DATA=$(cat ${EXT})

    printf "%s\n\n%s\n\n%s\n" "$TOP" "$DATA" "$BOT" > $FILE
}

function remove_extension()
{
    # ----------
    # Remove an 'extension' from a file
    # Args:
    #     $1: FILE to edit
    #     $2: the TAG of the extension
    # ----------
    local FILE="$1"
    local TAG="$2"

    local START=$(grep -noP "# ${TAG}-start" ${FILE} | cut -f 1 -d :)
    local END=$(grep -noP "# ${TAG}-end" ${FILE} | cut -f 1 -d :)

    ((START--))
    ((END++))

    local TOP=$(cat ${FILE} | head -n $START)
    local BOT=$(cat ${FILE} | tail -n +$END)

    printf "%s\n\n%s\n" "$TOP" "$BOT" > $FILE
}
