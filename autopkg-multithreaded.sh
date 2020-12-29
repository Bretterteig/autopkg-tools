#!/bin/zsh
setopt +o nomatch

# This trap is needed as all processes run in different runspace.
function cleanup(){
    for pid in $(${PGREP} -fi 'python /usr/local/bin/autopkg');do
        kill $pid
    done
}
trap cleanup 2

function print_help(){
    ${CAT} <<HELP 
Options avaiable:
  -r <recipe/directory> Runs only the specified recipe/recipies in directory.
  -k <option> Runs autopkg with optional keys.
  -t <count> Number of threads to use. Default is amount of cpu threads. More is not improving performance.
  -v <verbosity level  Verbose run (E.g -v vvv). Careful, long output.
  -h Show this message.
HELP
    exit 0
}

## BINARY PATHS ##
AUTOPKG="/usr/local/bin/autopkg"
MAKECATALOGS="/usr/local/munki/makecatalogs"
PLISTBUDDY="/usr/libexec/PlistBuddy"
BASENAME="/usr/bin/basename"
DATE="/bin/date"
LS="/bin/ls"
CAT="/bin/cat"
PGREP="/usr/bin/pgrep"
PS="/bin/ps"
###############



## Evaluate arguments ##
while getopts 'r:v:t:hk:' arg; do
    case $arg in
        r) recipe_list_file="$OPTARG" ;;
        v) verbose="$OPTARG" ;;
        t) thread_count="$OPTARG" ;;
        h) print_help ;;
        p) report_plist_dir="$OPTARG" ;;
        k) autopkg_keys="${autopkg_keys}--key=$OPTARG " ;;
        -) echo "Long opts not supported."; print_help; exit 1 ;;
        *) echo "Unknown option $arg:$OPTARG"; print_help; exit 0
    esac
done





## Evaluate input
# If parameter is given. Determine if file or folder.
if [[ -n $recipe_list_file ]];then
    if [[ -d $recipe_list_file ]];then
        echo "Running recipe dir \"$recipe_list_file\"\n"
        recipe_override_dirs=("$recipe_list_file")
        unset "recipe"
    elif [[ -r $recipe_list_file ]];then
        echo "Running recipes in $(${BASENAME} $recipe_list_file)\n"
    else
        echo "Path $recipe_list_file not found."
        exit 1
    fi
# If parameter is not given. Evaluate all override directories. Default to autopkg standard.
else    
    i=0
    while true ; do
        if ${PLISTBUDDY} -c "Print RECIPE_OVERRIDE_DIRS:$i" ~/Library/Preferences/com.github.autopkg.plist &>/dev/null; then  
            recipe_override_dirs+=($(${PLISTBUDDY} -c "Print RECIPE_OVERRIDE_DIRS:$i" ~/Library/Preferences/com.github.autopkg.plist))
        else
            break
        fi
        i=$(($i + 1))
    done

    if [[ -z $recipe_override_dirs ]];then
        recipe_override_dirs=(~"/Library/AutoPkg/RecipeOverrides")
    fi
fi

# If amount of threads is not given default to all
if [[ -z $thread_count ]];then
    thread_count=$(/usr/sbin/sysctl -n machdep.cpu.thread_count)
fi






# Build a list of recipes/task
if [[ -n $recipe_list_file ]];then
    for line in $(${CAT} $recipe_list_file);do
        recipe_list+=("${line}")
    done
else
    for recipe_override_dir in $recipe_override_dirs;do
        recipe_override_dir=("${recipe_override_dir:A}")
        if [[ -d $recipe_override_dir ]];then
            if ${LS} $recipe_override_dir/*.recipe &>/dev/null;then
                for recipe in $recipe_override_dir/*.recipe;do recipe_list+=("$recipe");done
            fi
        else
            echo "Directory $recipe_override_dir was not found.\n"
        fi
    done
fi


# Set all threads_pid to zero so tasks can be assigned
for i in $(/usr/bin/seq 1 1 $thread_count);do thread_pid[$i]="0"; done


# threads_active must be true so we can enter the loop. There is no do until
threads_active="true"
while [[ $threads_active == "true" ]];do
    # Iterate over all threads we manage
    for i in $(/usr/bin/seq 1 1 $thread_count);do
        # Assign new task sequence
        if [[ $thread_pid[$i] == "0" ]];then
            # If task is avaiable then assign it. Else skip check.
            if [[ -n $recipe_list ]];then
                thread_recipe[$i]="$(${BASENAME} -s '.recipe' "${recipe_list[1]}")"
                thread_start_time[$i]="$(${DATE} +%s)"
                echo -n "   + Processing $thread_recipe[$i]"
                [[ -n $verbose ]] && echo -n " in thread $i"
                echo ""
                if [[ -n $verbose ]];then
                    ${AUTOPKG} run "$(${BASENAME} -s '.recipe' "${recipe_list[1]}")" --quiet $autopkg_keys $([[ -n ${report_plist} ]] && echo "--report-plist \"${report_plist}/autopkg_report_$(${BASENAME} -s \'.recipe\' ${recipe_list[1]}).plist\"") -${verbose} &
                else
                    ${AUTOPKG} run "$(${BASENAME} -s '.recipe' "${recipe_list[1]}")" --quiet $autopkg_keys $([[ -n ${report_plist} ]] && echo "--report-plist \"${report_plist}/autopkg_report_$(${BASENAME} -s \'.recipe\' ${recipe_list[1]}).plist\"") 1>/dev/null &
                fi
                # Save process id so we can monitor it
                thread_pid[$i]="$!"
                # Remove assigned item form the task list
                recipe_list=("${recipe_list[@]:1}")
            else
                continue
            fi
        fi

        # Check if task is finished sequence
        if ! [[ $thread_pid[$i] == "0" ]] && [[ -n $thread_pid[$i] ]] && ! ${PS} $thread_pid[$i] &>/dev/null;then
            # Set to null if finished
            thread_pid[$i]="0"
            echo "   - Finished $thread_recipe[$i]. [$(($($DATE +%s)-$thread_start_time[$i]))s]"
        fi
    done

    # If the unique pid count is 1 there is only 1 thread or none. Check if the unique value is 0 to be sure that there is none.
    if [[ ${#${(u)thread_pid[@]}} == 1  ]] && [[ ${thread_pid[1]} == 0 ]] && [[ -z $recipe_list ]];then
        threads_active="false"
    fi

    # Sleep loop so it does not create system load.
    sleep 1
done