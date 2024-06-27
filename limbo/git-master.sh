### Imports section ##########################################################
function special_print() {
    local line="#####"
    local length=${#1}
    for ((i=1; i<$length; i++)); do
        line+="#"
    done
    echo "$line"
    echo "# $1 #"
    echo "$line"
}
##############################################################################

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -h, --help              Display this help message"
    echo " -ch, --checkout BRANCH  Checkout all submodules to the specified branch"
    echo " -pl, --pull             Pull changes from the remote repositories of all submodules"
    echo " -ps, --push             Push changes to the remote repositories of all submodules"
    echo " -fp, --force-push       Forcefully push changes to the remote repositories of all submodules"
    echo " -c, --commit MESSAGE    Commit changes in all submodules and the parent repository with the given message"
    echo " -s, --squash MESSAGE [TIME_WINDOW]"
    echo "                         Squash commits in all submodules and the parent repository with the given message"
    echo "                         and an optional time window (a bash date e.g., '1 day ago' or '12 hours ago')"
}

get_submodules_paths() {
    local dir="$1"
    if [ -f "$dir/.gitmodules" ]; then
        awk -F' = ' '/\tpath / {print $2}' "$dir/.gitmodules" | while IFS= read -r submodule_path; do
            echo "${dir}/$submodule_path"
            if [ -f "${dir}/$submodule_path/.gitmodules" ]; then
                get_submodules_paths "${dir}/$submodule_path"
            fi
        done
    fi
}

get_submodules_names() {
    local dir="$1"
    if [ -f "$dir/.gitmodules" ]; then
		local submodule_paths
		local submodule_names
        mapfile -t submodule_paths < <(awk -F' = ' '/\tpath / {print $2}' "$dir/.gitmodules")
		mapfile -t submodule_names < <(awk -F'"' '/\[submodule / {print $2}' "$dir/.gitmodules") 
        local len=${#submodule_paths[@]}
		local i
        for ((i=0; i<$len; i++)); do
			local submodule_path="${dir}/${submodule_paths[$i]}"
			local submodule_name="${submodule_names[$i]}"
            echo "$submodule_name"
            if [ -f "$submodule_path/.gitmodules" ]; then
                get_submodules_names "$submodule_path"
            fi
        done
    fi
}

generate_indents() {
    local dir="$1"
    local indent="${2:-0}"

    if [ -f "$dir/.gitmodules" ]; then
        local submodule_paths
        mapfile -t submodule_paths < <(awk -F' = ' '/\tpath / {print $2}' "$dir/.gitmodules")

        local len=${#submodule_paths[@]}
        local i
        for ((i=0; i<$len; i++)); do
            local submodule_path="${dir}/${submodule_paths[$i]}"
            echo "$indent"
            generate_indents "$submodule_path" "$((indent + 1))"
        done
    fi
}

ones(){
	local length=$1
	local arr=()
	local i
	for ((i=0; i<$length; i++)); do
		arr+=(1)
	done
	
	#return arr
	echo "${arr[@]}"
}

AND() {
    local -a A=("${!1}")  
    local -a B=("${!2}")  
    local O=()     

    local len=${#A[@]}  
    local i
    for ((i=0; i<len; i++)); do
        if [[ "${A[i]}" == "${B[i]}" ]]; then
            O+=(1) 
        else
            O+=(0) 
        fi
    done

    echo "${O[@]}" 
}

NOT() {
    local -a A=("${!1}") 
    local O=()     

    local len=${#A[@]}  
    local i
    for ((i=0; i<len; i++)); do
        if [[ "${A[i]}" -eq 0 ]]; then
            O+=(1)  
        elif [[ "${A[i]}" -eq 1 ]]; then
            O+=(0)  
        else
            echo "Error: Input array must contain only 0 or 1"
            return 1
        fi
    done

    echo "${O[@]}"  # Print the result array
}

find_paths() {
    local -a A=("${!1}")   
    local -a Ref=("${!2}") 
    local mask=()   
	
    for ref_elem in "${Ref[@]}"; do
        local found=0
        for a_elem in "${A[@]}"; do
            if [[ "$ref_elem" == "$a_elem" ]]; then
                found=1
                break
            fi
        done
        mask+=("$found")
    done

    echo "${mask[@]}"
}

print_tree() {
	local -a names=("${!1}")   
	local -a indents=("${!2}") 
	local -a mask=("${!3}")    
	
	local RED='31'

	local len=${#names[@]}
	local i
	for ((i=0; i<$len; i++)); do
		local indent_level="${indents[$i]}"
		local submodule_name="${names[$i]}"
		local indent=""
		for ((j=0; j<$indent_level; j++)); do
			indent+="    "
		done
		if [[ "${mask[$i]}" -eq 1 ]]; then
			echo "${indent}└── ${submodule_name}"  # Print in normal color
		else
			echo_colored "${indent}└── ${submodule_name}" "$RED"
		fi
	done
}

sort_deepest_first() {
	#Sort directories deepest first.
    local paths=("$@") 
    IFS=$'\n' sorted_paths=($(sort -r <<<"${paths[*]}"))
    unset IFS
    echo "${sorted_paths[@]}"
}
paths=($(sort_deepest_first "${paths[@]}"))

sort_shallowest_first() {
    # Sort directories shallowest first
    local paths=("$@")
    IFS=$'\n' sorted_paths=($(sort <<<"${paths[*]}"))
    unset IFS
    echo "${sorted_paths[@]}"
}

remove_duplicate_paths() {
    local paths=("$@")  
    declare -A unique_paths
    for path in "${paths[@]}"; do
        base=$(basename "$path")
        if [[ -z ${unique_paths[$base]} || ${#path} -lt ${#unique_paths[$base]} ]]; then
            unique_paths["$base"]="$path"
        fi
    done

    unique_paths_array=("${unique_paths[@]}")
	# Print the unique paths
	for path in "${unique_paths_array[@]}"; do
		echo "$path"
	done
	
	# To capture the returned value 
	# paths_no_dups =($(remove_duplicate_paths "${paths[@]}"))
}

find_unique_paths() {
    declare -a paths=("${!1}")
    declare -a paths_no_dups=("${!2}")
    declare -a unique_paths=()
    
    for path in "${paths[@]}"; do
        found=false
        for dups_path in "${paths_no_dups[@]}"; do
            if [[ "$path" == "$dups_path" ]]; then
                found=true
                break
            fi
        done
        if [[ $found == false ]]; then
            unique_paths+=("$path")
        fi
    done
    
	for path in "${unique_paths[@]}"; do
		echo "$path"
	done
}

read_config_file() {
    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line; do
            # Skip empty lines and comments
            if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                local key=$(awk -F '=' '{print $1}' <<< "$line")
                local value=$(awk -F '=' '{$1=""; print substr($0,2)}' <<< "$line")
                
                # Trim leading and trailing whitespace from key and value
                key=$(echo "$key" | tr -d '[:space:]')
                value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                
                case "$key" in
                    ignore_paths)
                        #ignore_paths="$value"
						IFS=',' read -r -a ignore_paths <<< "$value"
                        ;;
                esac
            fi
        done < "$CONFIG_FILE"
    else
        echo "Configuration file $CONFIG_FILE not found."
        exit 1
    fi
}

process_arguments() {
    # Check if no options given
    if [ $# -eq 0 ]; then
        echo "No arguments provided. Please provide either 'rebase' or 'commit'."
        echo ""
        usage
        exit 1
    fi
    # Loop through all the possible entries
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help|help )
                usage
                ;;
            -ch|--checkout|checkout) 
                if [[ -n "$2" ]]; then
                    checkout_paths "$2" "${paths[@]}"
                    shift
                else
                    echo "Error: rebase requires a valid branch name"
                    exit 1
                fi
                ;;
            -pl|--pull|pull) 
                pull_paths "${paths[@]}"
                shift
                ;;
            -ps|--push|push) 
                push_paths "${paths[@]}"
                shift
                ;;
            -fp|--force-push|force-push) 
                force_push_paths "${paths[@]}"
                shift
                ;;
            -st|--status|status) 
                status_paths "${paths[@]}"
                shift
                ;;
            -c|--commit|commit)
                if [[ -n "$2" ]]; then
                    commit_paths "$2" "${paths[@]}"
                    shift
                else
                    echo "Error: commit requires a comment"
                    exit 1
                fi
                ;;
            -s|--squash|squash)
                if [[ -n "$2" ]]; then
                    if [[ -n "$3" ]]; then
                        squash_commits "$2" "${paths[@]}" "$3"
                        shift
                    else
                        squash_commits "$2" "${paths[@]}"
                        shift
                    fi
                else
                    echo "Error: squash requires a comment"
                    exit 1
                fi
                ;;
            *)
                usage
                exit 1
                ;;
        esac
        shift
    done
}

function status_paths() {
	local -a paths=("${!1}")
	special_print "Submodules short status"
    for path in "${paths[@]}"; do
		status=$(git -C "$path" status --short)
        if [[ -n "$status" ]]; then
            echo "$path"
            echo "$status"
        fi
    done
}

function checkout_branch() {
    local branch="$1"
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
        git checkout "$branch"
    else
        echo "Error: Branch '$branch' does not exist."
        exit 1
    fi
}

function checkout_paths() {
    local branch="$1"
    local paths=("${!2}")
	special_print "Checkout to $branch"
    for path in "${paths[@]}"; do
		echo "$path"
        git -C "$path" checkout_branch "$branch"
    done
}

function pull_paths() {
    local paths=("${!1}")
    special_print "Pull"
    for path in "${paths[@]}"; do
        echo "$path"
        git -C "$path" pull
    done
}

function push_paths() {
    local paths=("${!1}")
    special_print "Push"
    for path in "${paths[@]}"; do
        echo "$path"
        git -C "$path" push
    done
}

function force_push_paths() {
    local paths=("${!1}")
    special_print "Force Push"
    for path in "${paths[@]}"; do
        echo "$path"
        git -C "$path" push --force
    done
}

function squash_commits() {
    local message="$1"
    local paths=("${@:2:$#-2}")
    local time_window="${@: -1}"
    # If no message is provided, use the current date as the default value
    if [[ -z "$message" ]]; then
        message=$(date)
    fi
    # If no third argument is provided, use "1 day ago" as the default value
    if [ -n "$time_window" ]; then
        time_window="1 day ago"
    fi
    special_print "Squash"	
	for path in "${paths[@]}"; do
		latest_commit_hash=$(git -C "$path" rev-parse HEAD)
		after_time_hash=$(git -C "$path" rev-list --after="$time_window" --reverse HEAD | head -n 1)
		before_time_hash=$(git -C "$path" rev-list -n 1 --before="$time_window" HEAD)	
		if [ "$after_time_hash" != "$latest_commit_hash" ]; then
			echo "$path"
			git -C "$path" reset --soft "$before_time_hash"
			git -C "$path" commit -m "$message"
		fi
	done
	latest_commit_hash=$(git rev-parse HEAD)
	after_time_hash=$(git rev-list --after="$time_window" --reverse HEAD | head -n 1)
	before_time_hash=$(git rev-list -n 1 --before="$time_window" HEAD)
	if [ "$after_time_hash" != "$latest_commit_hash" ]; then
		echo "Parent directory"
		git reset --soft "$before_time_hash"
		git commit -m "$message"
	fi
}

function commit_paths() {
    local message="$1"
    local paths=("${!2}")
	special_print "Commit"
    for path in "${paths[@]}"; do
		# Check if there are changes to commit
        if ! git -C "$path" diff --exit-code --quiet; then
			echo "$path"
			git -C "$path" add .
            git -C "$path" commit -m "$message"
        fi
    done
	# Check if there are changes to commit in the parent module
    if ! git diff --exit-code --quiet; then
		echo "Parent directory"
		git add .
        git commit -m "$message"
    fi
}


main() {
    CONFIG_FILE=".gitmaster"
	dir="."
	
	# Commit CMakeConfigs
	# Push   CMakeConfigs
	# Update --remote all
	# Commit recursive
	
	
	
	# this is slow
	# init arrays #######################
	paths=()
	while IFS= read -r line; do
	paths+=("$line")
	done < <(get_submodules_paths "$dir")
	names=() 
	while IFS= read -r line; do
		names+=("$line")
	done < <(get_submodules_names "$dir")
	indents=($(generate_indents "$dir")) 
	len=${#paths[@]}
	tree_mask=($(ones $len))
	#####################################
	
	# this is the slowest part
    read_config_file # ignore_paths
	
	# process config #############################
	ignore_mask=($(find_paths ignore_paths[@] paths[@]))
	ignore_mask=($(NOT ignore_mask[@]))
	tree_mask=($(AND ignore_mask[@] tree_mask[@]))
	##############################################
        	
	print_tree names[@] indents[@] tree_mask[@]
}
