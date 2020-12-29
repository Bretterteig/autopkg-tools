#!/bin/zsh
# Config
DATATYPETOREMOVE=(".dmg" ".pkg" ".app" ".zip" ".7z" ".rar" ".plist")
MAXSEARCHDEPTH=5
CACHEDAYS=90


# Binaries
FIND="/usr/bin/find"
PLISTBUDDY="/usr/libexec/PlistBuddy"
RM="/bin/rm"

# Get cache directory
cache_dir=$(${PLISTBUDDY} -c 'print CACHE_DIR' ~/Library/Preferences/com.github.autopkg.plist 2>/dev/null)
if [[ -z $cache_dir ]] || ! [[ -d $cache_dir ]];then
    if [[ -d ~/Library/AutoPkg/Cache ]];then
        cache_dir=~/Library/AutoPkg/Cache
    else
        echo "Could not determine cache dir"
        exit 1
    fi
fi

# Arguments based on file types listed in CACHEDATATYPETOREMOVE
find_args=$(for ((i = 1; i < ((${#DATATYPETOREMOVE[@]} + 1)); i++)); do
    # File type
    echo -n "-iname \"*${DATATYPETOREMOVE[i]}\" "
    # Add "or" parameter if not last argument
    [[ $i != ${#DATATYPETOREMOVE[@]} ]] && echo -n "-o "
done)

# Add arguments for time cache should be kept. Deny search inside app bundles to not corrupt apps
find_cmnd="${FIND} -E $cache_dir \( \( -mtime +${CACHEDAYS}d -and -atime +${CACHEDAYS}d -and -Btime +${CACHEDAYS}d \) -maxdepth $MAXSEARCHDEPTH \( $find_args \) -and \( -not -iregex \".*\.app\/.+\" \) \)"

# Remove files
echo "Cleaning cache."
IFS=$'\n'
for line in $(eval $find_cmnd); do
    echo "  > Deleting $line"
    ${RM} -rf "$line"
done

