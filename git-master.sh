#!/bin/bash

#Docstring
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

generate_submodule_tree() {
    local dir="$1"
    local indent="$2"

    # Check if .gitmodules file exists
    if [ -f "$dir/.gitmodules" ]; then
        # Use awk to directly extract submodule paths and iterate over them
        awk -F'"' '/\[submodule / {print $2}' "$dir/.gitmodules" | while IFS= read -r submodule; do
            # Form the submodule path
            submodule_path="${dir}/$submodule"
            submodule_path="${submodule_path#./}"
            
            # Extract only the submodule name
            submodule_name="${submodule_path##*/}"
            
            # Print submodule name with proper indentation
            echo "${indent}└── ${submodule_name}"
            
            # If submodule has its own .gitmodules, recursively call function with increased indentation
            if [ -f "$submodule_path/.gitmodules" ]; then
                generate_submodule_tree "$submodule_path" "${indent}  "
            fi
        done
    fi
}

get_all_submodules() {
    local dir="$1"

    # Check if .gitmodules file exists
    if [ -f "$dir/.gitmodules" ]; then
        # Use awk to directly extract submodule paths and iterate over them
        awk -F'"' '/\[submodule / {print $2}' "$dir/.gitmodules" | while IFS= read -r submodule; do
            # Form the submodule path
            submodule_path="${dir}/$submodule"
            submodule_path="${submodule_path#./}"
            
            # Print the submodule path
            echo "$submodule_path"
            
            # Recursively get submodules if the submodule has its own .gitmodules
            if [ -f "$submodule_path/.gitmodules" ]; then
                get_all_submodules "$submodule_path"
            fi
        done
    fi
}

paths=() 
while IFS= read -r line; do
    paths+=("$line")
done < <(get_all_submodules .)

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
paths_no_dups=($(remove_duplicate_paths "${paths[@]}"))
paths_no_dups=($(sort_directories "${paths_no_dups[@]}"))

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
paths_only_dups=($(find_unique_paths paths[@] paths_no_dups[@]))
paths_only_dups=($(sort_directories "${paths_only_dups[@]}"))


# Check if not options given
if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide either 'rebase' or 'commit'."
	echo ""
	usage
    exit 1
fi

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

function status_paths() {
	local paths=("$@")
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
    local paths=("${@:2}")
	special_print "Checkout to $branch"
    for path in "${paths[@]}"; do
		echo "$path"
        git -C "$path" checkout_branch "$branch"
    done
}

function pull_paths() {
    local paths=("$@")
    special_print "Pull"
    for path in "${paths[@]}"; do
        echo "$path"
        git -C "$path" pull
    done
}

function push_paths() {
    local paths=("$@")
    special_print "Push"
    for path in "${paths[@]}"; do
        echo "$path"
        git -C "$path" push
    done
}

function force_push_paths() {
    local paths=("$@")
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
    local paths=("${@:2}")
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

# Looping through all the possible entries
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