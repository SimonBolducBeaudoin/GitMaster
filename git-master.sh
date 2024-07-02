#!/bin/bash
gitmod ()(
# A big function using a subshell to separate scopes
# This helps with error handling (just use exit 1 instead of exit 1)
# and makes all function and variables local

gitmod_help() {
local help_message="
An extension of git for projects with git modules.

Usage: gitmod [-h | --help] [-C <path>] <command> [<args>]

These are the supported commands for now :
  tree        prints the tree of modules
  climb       Helps to recursively iterate over modules
  grow        Add and commit from leaves to trunk
  checkout    Checkouts the branches defined in .gitmodules (trunk first)
  pull        pulls and stop at conflicts (trunk first)
  add         Adds files to the index for each module (leaves first)
  reset       git reset all modules
  commit      Record changes to the rep4Zository for each module and stops at conflicts (leaves first)

Example usage:
  # The tree of modules as a trunk branches and leaves
  gitmod tree
  
  # climb is similar but more powerful than git submodule --foreach
  gitmod climb --help
  
  # Resolving detached head states for each modules
  gitmod checkout -C /path/to/repo 
  
  # Getting updates
  gitmod pull --rebase
  
  # Only committing commit pointers (aka the state of each module)
  gitmod add -C /path/to/repo --modules
  gitmod commit -m 'Updating modules'
	"
	echo "$help_message"
}

climb_help() {
local help_message="
A helper to iterate over a tree of git modules.
Climbing up or down the tree of git modules calling <func> every step of the way.

Usage: gitmod [...] climb <func> [options]

Options:
	  --leaves                Execute on leaves (default is false)
	  --branches              Execute on leaves (default is false)
	  --trunk                 Execute on trunk  (default is false)
	  --up                    Climb up the tree (default)
	  --down                  Climb down the tree
	  --help                  Display this help message

Help:
To see what trunk, branches, and leaves are, call
	gitmod tree.
When using --trunk, func will be called on the trunk using \$path=\$dir (i.e. trunk has no parents).

Examples:

	# Use git -C \$path to call git in the current submodule (inside the current module)
	dummy() {
		# Climb will recursively call this function in each module
		dir='\$1'    # \$1 is the directory of that module
		path='\$2'   # \$2 is the path towards the current submodule (inside module)
		name='\$3'   # \$3 is the name of the current submodule (inside module)
		echo ' Module \$3 in directory \$1 '
		git -C '\$path' log --all --decorate --oneline --graph -n1
	}
	gitmod climb dummy --trunk --leaves --down

	# use get_module_key '.../gitmodules' '\$name' 'key'
	# to read the current module's .gitmodule file
	# and get the value (of key) for the current submodule
	# The keys path and url are mandatory (git submodule rules)
	# And the keys branch and update can be defined by the user.
	say_url() {
		dir='\$1'
		path='\$2'
		name='\$3'
		url=\$(get_module_key "\$dir/.gitmodules" "\$name" "url")
		echo '\$name : \$url'
	}
	gitmod climb say_url --trunk --branches --leaves --up
	"
	echo "$help_message"
}

tree_help() {
local help_message="	
Shows the module tree.
Usage: gitmod [...] tree"
	echo "$help_message"
}

checkout_help() {
local help_message="
For each module in .gitmodules gets the value of branch
and then call 'git checkout branch' for that module.
It doesn't checkout the trunk.
The checkout order is then branches-->leaves

Usage: gitmod [...] checkout"
echo "$help_message"
}

pull_help() {
local help_message="
For each module in .gitmodules gets the value of update (merge or rebase)	
to determine which type of pull it should do.
If conflicts occurs during a pull it stops there (doesn't pull the whole project).
You must then solve the conflict for that specific project and pull gitmod pull again.
	
The pull order is then trunk-->branches-->leaves

Usage: gitmod [...] pull 

Options:
      -r | --rebase 		 forces pull --rebase for all module
      --merge | --no-rebase forces pull --no-rebase for all module"
echo "$help_message"
}

add_help() {
local help_message="
Add changes (all,module pointers only or all minus module pointers) to all modules.
By default it adds all changes that aren't module.
This is because one might be tricked into think that
gitmod add followed by git mod commit would have the
same effect as commit the whole local super repo.
If you which to have this effect use  gitmod grow,
which add and commits leaves before add and commit branches.

Usage: gitmod [...] add [options] 
	echo
Options:
	   --no-module           only add changes that are not modules (default)
      -m | --module		 only add changes commits pointer of modules 
      -a | --all   		 add all changes "
echo "$help_message"
}

reset_help() {
local help_message="
Resets all modules (git reset).

Usage: gitmod [...] reset "
echo "$help_message"
}

commit_help() {
local help_message="
Commit all staged changes in all modules with the same message.

Usage: gitmod [...] commit -m <message> [options]
		echo
Options:
      -m <message>      Commit message
      --[no-]trunk		 
      --[no-]branch   	 
      --[no-]leaves   	 "
echo "$help_message"
}

grow_help() {
local help_message="
Add and commit each modules leaves --> trunk 

Usage: gitmod [...] grow -m <message> [options] 

Options:
		-m | --message       commit message (mendatory) 
      -a | --all   		 add all changes (default) 
     --module		         only add changes commits pointer of modules 
	   --no-module           only add changes that are not modules"
echo "$help_message"
}

mute_help() {
local help_message="
Prevents to push to origin by setting origin url to no_push.
Goes through each module one by one prompting (Y/N) if the module should be muted.

Usage: gitmod [...] mute [options]

Options :
		--undo 			Reset the push url to be equal to the pull url.
"
echo "$help_message"
}

prompt_help() {
local help_message="
Promts the user (Y/N) one module at a time to trigger some given action (func).
 
Usage: gitmod [...] prompt func [options]" 
echo "$help_message"
}

echo_colored() {
	# see ANSI color codes
	local message="$1" # Message to print
	local color="$2"   # Color code
	echo -e "\e[${color}m${message}\e[0m"
}

get_yes_no() {
	local prompt answer default

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-d|--default)
				if [[ "$2" =~ ^[YyNn]$ ]]; then
					default="$2"
					shift 2
				else
					echo "Invalid default value. Use 'Y' or 'N'."
					exit 1
				fi
				;;
			*)
				prompt="$*"
				break
				;;
		esac
	done

	while true; do
		if [ -n "$default" ]; then
			read -rp "$prompt (Y/N) [${default}]: " answer
			answer="${answer:-$default}"
		else
			read "$prompt (Y/N): " answer
		fi
		
		case "$answer" in
			[Yy]* ) echo true; return 0;;
			[Nn]* ) echo false; return 0;;
			* ) echo "" ; echo -n "Please answer Y or N.";;
		esac
	done
}

SUBMODULE_NAME='^[[:space:]]*\\[submodule[[:space:]]*\"(.+)\"[[:space:]]*\\][[:space:]]*$'
TRIM='^[[:space:]]+|[[:space:]]+$'
COMMENT='^[[:space:]]*#'

get_module_names(){
	local file="$1"
	awk -v regex="$SUBMODULE_NAME" 'match($0, regex, arr) {print arr[1]}' "$file"
}

get_module_key(){
	local file="$1"
	local name="$2"
	local key="$3"
	
	local awk_prgm='
	BEGIN { in_table = 0 }
		function trim(str) { gsub( trim_reg, "", str); return str }
	$0 ~ comment { next }  
	match($0, table_head, matches) {
		if (matches[1] == table_name) { in_table = 1 } else { in_table = 0 }
		}
	in_table && trim($1) == key { print trim($2) }
		'

	awk -F= -v table_name="$name" -v key="$key" -v table_head="$SUBMODULE_NAME" -v trim_reg="$TRIM" -v comment="$COMMENT" "$awk_prgm" "$file"
}

gitmod() {
	local dir="."
	local command=""
	local CMDARGS=()
		
	gitmod_parse() {
		local -n dir_ref=$1
		local -n command_ref=$2
		local -n cmd_args_ref=$3
		shift 3

		local valid_commands=("tree" "climb" "prompt" "grow" "checkout" "pull" "add" "reset" "commit" "mute")

		while (( "$#" )); do
			case "$1" in
				-C)
					dir_ref="$2"
					shift 2
					;;
				--help|-h)
					cmd_args_ref+=("--help")
					shift
					;;
				--*)
					cmd_args_ref+=("$1")
					shift
					;;
				-*)
					cmd_args_ref+=("$1")
					shift
					;;	
				*)
					if [ -z "$command_ref" ]; then
						if [[ " ${valid_commands[@]} " =~ " $1 " ]]; then
							command_ref="$1"
						else
							echo "Invalid command: $1"
							showhelp_ref=true
						fi
						if [[ "$command_ref" == "reset" ]] ; then
							command_ref="reset_modules" # A consequence of the fact that I'm avoiding collision with the reset function.
						fi
					else
						cmd_args_ref+=("$1")
					fi
					shift
					;;
			esac
		done
	}

	gitmod_parse dir command CMDARGS "$@"

	if [ -z "$command" ] ; then
	   gitmod_help
	   exit 1
	fi
	
	# Execute the command with the collected flags
	"$command" "${CMDARGS[@]}"
	
	unset -f gitmod_parse
}

climb() {
	local func=""
	local LEAVES=false
	local BRANCHES=false
	local TRUNK=false
	local UPWARD=true
	local SHOW_HELP=false
	
	local ISTRUNK=false
	local ISLEAVES=false
	local -i DEPTH=0
	local -i MAXDEPTH=5
	
	climb_parse() {
		local -n leaves_ref=$1
		local -n branches_ref=$2
		local -n trunk_ref=$3
		local -n upward_ref=$4
		local -n show_help_ref=$5
		local -n func_ref=$6
		
		local non_flag_args=0

		shift 6

		#dir should normally have been declared globally but in case it asn't
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--leaves)
					leaves_ref=true
					shift
					;;
				--branches)
					branches_ref=true
					shift
					;;
				--trunk)
					trunk_ref=true
					shift
					;;
				--up)
					upward_ref=true
					shift
					;;
				--down)
					upward_ref=false
					shift
					;;
				--help)
					show_help_ref=true
					shift
					;;
				-*)
					echo "Unknown option: $1"
					exit 1
					;;
				*)
					non_flag_args=$((non_flag_args + 1))
					if [[ $non_flag_args -gt 1 ]]; then
						echo "Unknown option: $1"
						exit 1
					fi
					func_ref="$1"
					shift
					;;
			esac
		done
	}
	
	climbing() {
		local func="$1"
		local dir="$2"
		local path="$3"
		local module="$4"
		
		 (( DEPTH += 1 ))
		
		if (( DEPTH > MAXDEPTH )); then
			echo "Max depth reached in $dir"
			exit 1
		fi
		
		# On the way up
		if (( DEPTH > 0 ))	&& $UPWARD && [ -f "$dir/$path/.gitmodules" ] && $BRANCHES ; then
			"$func" "$dir" "$dir/$path" "$module"
			
		fi
		
		if [ -f "$dir/$path/.gitmodules" ] ; then
			local names=()
			mapfile -t names < <(get_module_names "$dir/$path/.gitmodules")
			local len=${#names[@]}
			local i
			for ((i=0; i<$len; i++)); do
				local name="${names[$i]}"
				local subpath="$(get_module_key "$dir/$path/.gitmodules" "$name" "path")"
				climbing "$func" "$dir/$path" "$subpath" "$name"
			done
		elif $LEAVES && (( DEPTH < MAXDEPTH )); then
			ISLEAVES=true
		   "$func" "$dir" "$dir/$path" "$module"
			ISLEAVES=false			
			
		fi
		
		# On the way down
		if (( DEPTH > 0 ))	&& ! $UPWARD && [ -f "$dir/$path/.gitmodules" ] && $BRANCHES ; then
			"$func" "$dir" "$dir/$path" "$module"
			
		fi
		
		(( DEPTH -= 1 ))
	}
	
	climb_parse LEAVES BRANCHES TRUNK UPWARD SHOW_HELP func "${@}"
		
	if $SHOW_HELP; then
		climb_help
		exit 1
	fi
	
	if $TRUNK && $UPWARD; then
		ISTRUNK=true
		"$func" "$dir" "$dir" "Trunk"
		ISTRUNK=false
		
	fi
	
	# Now it's time to start climbinb fr
	if [ -f "$dir/.gitmodules" ]; then		
		local names=()
		mapfile -t names < <(get_module_names "$dir/.gitmodules")
		local len=${#names[@]}
		local i
		for ((i=0; i<$len; i++)); do
			local name="${names[$i]}"
			local path="$(get_module_key "$dir/.gitmodules" "$name" "path")"
			climbing "$func" "$dir" "$path" "$name"
			
		done
	fi
	
	if $TRUNK && ! $UPWARD; then
		ISTRUNK=true
		"$func" "$dir" "$dir" "Trunk"
		ISTRUNK=false
		
	fi	
	 
	unset -f climbing -f climb_parse
}

prompt() {
	local SHOW_HELP=false
	local RED='31'
	local GREEN='32'
	local MESSAGE=""
	local FUNC=""
	local YALL=false
	
	prompt_parse() {
		local -n show_help_ref=$1
		local -n message_ref=$2
		local -n func_ref=$3
		local -n yall_ref=$4
		
		local non_flag_args=0

		shift 4
		
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				-m | --message)
					if [[ -n "$2" && "$2" != -* ]]; then
						message_ref="$2"
						shift 2
					else
						echo "Error: -m requires a commit message."
						exit 1
					fi
					;;
				-y | --yes)
					yall_ref=true
					shift
					;;
				-*)
					echo "Unknown option: $1"
					exit 1
					;;
				*)
					non_flag_args=$((non_flag_args + 1))
					if [[ $non_flag_args -gt 1 ]]; then
						echo "Unknown option: $1"
						exit 1
					fi
					func_ref="$1"
					shift
					;;
			esac
		done
	}
	
	prompt_tree(){
		local depth=$DEPTH #defined in climb
		local dir="$1"
		local path="$2"
		local name="$3"
		local answer=false
		local message=""
		local padding
		local max_length=50
		local FUNCRET=""
		
		local indent=""
		for ((j=0; j<$depth; j++)); do
			indent+="    "
		done
		
		current_branch=$(git -C "$path" rev-parse --abbrev-ref HEAD)
		if $ISTRUNK ; then
			repo_path=$(git -C "$path" rev-parse --show-toplevel)
			repo_name=$(basename "$repo_path")
			message="${repo_name} ($current_branch)"
			local color="$RED"
			echo -e -n "\e[${color}m${message}\e[0m"
		elif $ISLEAVES ; then
			message="${indent}└── ${name} ($current_branch)"
			local color="$GREEN"
			echo -e -n "\e[${color}m${message}\e[0m"
		else 
			message="${indent}└── ${name} ($current_branch)"
			echo -n "$message"
		fi
				
		if $YALL ; then
			echo ""
			answer=true
		else
			length="${#message}"
			padding=$((max_length - length))
			padding=$((padding > 0 ? padding : 0))
			printf "%*s" "$padding" ""
			answer="$(get_yes_no -d N "")"
		fi
		
		if $answer ; then
			FUNCRET="$($FUNC "$dir" "$path" "$name")"
		fi
		
		if [ -n "$FUNCRET" ] ; then
			if $ISTRUNK ; then
			echo -e "\e[${color}m${FUNCRET}\e[0m"
			elif $ISLEAVES ; then
				message="${indent}    $FUNCRET"
				echo -e "\e[${color}m${message}\e[0m" 
			else
				echo "${indent}    $FUNCRET"
			fi
		fi
	}
	
	prompt_parse SHOW_HELP MESSAGE FUNC YALL "${@}"
	
	if $SHOW_HELP; then
		prompt_help
		exit 1
	fi
	
	echo "$MESSAGE"
	gitmod climb prompt_tree --trunk --branches --leaves --up
	
	unset -f prompt_tree -f prompt_parse
}

tree() {
	local SHOW_HELP=false
	local RED='31'
	local GREEN='32'
	
	tree_parse() {
		local -n show_help_ref=$1

		shift 1

		#dir should normally have been declared globally but in case it asn't
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
	}
	
	draw_tree(){
		local depth=$DEPTH #defined in climb
		local dir="$1"
		local path="$2"
		local name="$3"
		
		local indent=""
		for ((j=0; j<$depth; j++)); do
			indent+="    "
		done
		
		current_branch=$(git -C "$path" rev-parse --abbrev-ref HEAD)
		if $ISTRUNK ; then
			repo_path=$(git -C "$path" rev-parse --show-toplevel)
			repo_name=$(basename "$repo_path")
			echo_colored "${repo_name} ($current_branch)" "$RED"
		elif $ISLEAVES ; then
			echo_colored "${indent}└── ${name} ($current_branch)" "$GREEN"
		else 
			echo "${indent}└── ${name} ($current_branch)"
		fi
		
	}
	
	tree_parse SHOW_HELP "${@}"
	if $SHOW_HELP; then
		tree_help
		exit 1
	fi
	
	echo "Legend :"
	echo_colored "	trunk" "$RED"
	echo "	branch"
	echo_colored "	leaves" "$GREEN"
	echo ""
	echo "Tree :"
	
	gitmod climb draw_tree --trunk --branches --leaves --up
	
	unset -f draw_tree -f tree_help -f tree_parse
}

checkout() {
	local SHOW_HELP=false
	local GREEN='32'
	
	checkout_parse() {
		local -n show_help_ref=$1
		shift 1

		#dir should normally have been declared globally but in case it asn't
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
	}
	
	checkout_parse SHOW_HELP "${@}"
	if $SHOW_HELP; then
		checkout_help
		exit 1
	fi
	
	checkout_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		local branch=$(get_module_key "$dir/.gitmodules" "$name" "branch")
		if [ -n "$branch" ]; then
			echo_colored "$path checkout $branch" "32" #green
			git -C "$path" checkout "$branch" 
		fi
	}
	climb checkout_module --branches --leaves --up
	
	unset -f checkout_module -f checkout_parse
}

pull() {
	local SHOW_HELP=false
	local FORCE_REBASE=false
	local FORCE_MERGE=false
	
	pull_parse() {
		local -n show_help_ref=$1
		local -n force_rebase_ref=$2
		local -n force_merge_ref=$3
		shift 3

		#dir should normally have been declared globally but in case it asn't
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				-r | --rebase)
					force_rebase_ref=true
					shift
					;;
				--merge | --no-rebase)
					force_merge_ref=true
					shift
					;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
	}
	pull_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		local branch
		local update
		local pull_type
		
		echo_colored "$path pull " "32" #green
		branch=$(get_module_key "$dir/.gitmodules" "$name" "branch")
		update=$(get_module_key "$dir/.gitmodules" "$name" "update")
		
		if [ -n "$branch" ]; then 
			git -C "$path" checkout "$branch" --quiet
		fi
		
		if $FORCE_REBASE ; then
			pull_type="--rebase"
		elif $FORCE_MERGE ; then
			pull_type="--no-rebase"
		elif [ -n "$update" ]; then
			pull_type=$(get_module_key "$dir/.gitmodules" "$name" "update")
		fi
		
		# only pull module for which branch is defined
		# This sorta inforce the use of .gitmodule branch and update.
		if [ -n "$branch" ]; then 
			git -C "$path" pull "$pull_type"
		fi
	}
	
	pull_parse SHOW_HELP FORCE_REBASE FORCE_MERGE "${@}"
	if $SHOW_HELP; then
		pull_help
		exit 1
	fi
	
	climb pull_module --trunk --branches --leaves --up
	
	unset -f pull_module -f pull_parse
}

add() {
	local SHOW_HELP=false
	local MODULE=false
	local NOMODULE=false
	local ALL=false
	
	add_parse() {
		local -n show_help_ref=$1
		local -n module_ref=$2
		local -n all_ref=$3
		local -n nomodule_ref=$4
		shift 4
		#dir should normally have been declared globally but in case it asn't
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				-m | --module)
					module_ref=true
					shift
					;;
				-a | --all)
					all_ref=true
					shift
					;;
				--no-module)
					nomodule_ref=true
					shift
					;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
	}
	add_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		
		echo_colored "$dir add" "32" #green
		
		if $MODULE ; then
			git -C "$dir" add name
		elif $NOMODULE ; then
			git -C "$path" add --all 
			if ! $ISTRUNK ; then
				git -C "$dir" reset name 
			fi
		else #ALL
			git -C "$path" add --all
		fi
	}
	
	add_parse SHOW_HELP MODULE ALL NOMODULE "${@}"
	if $SHOW_HELP; then
		add_help
		exit 1
	fi
	
	if $MODULE ; then
		climb add_module --branches --leaves --up
	elif $NOMODULE ; then
		climb add_module --trunk --branches --leaves --up
	else #ALL
		climb add_module --trunk --branches --leaves --up
	fi
	
	unset -f add_module -f add_parse 
}

# I'm avoiding collision with bash's reset function for now
reset_modules() {
	local SHOW_HELP=false
	
	reset_parse() {
		local -n show_help_ref=$1
		shift 1
		#dir should normally have been declared globally but in case it asn't
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
	}
	reset_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		echo_colored "$path reset" "32" #green
		git -C "$path" reset
	}
	
	reset_parse SHOW_HELP "${@}"
	if $SHOW_HELP; then
		reset_help
		exit 1
	fi
	
	climb reset_module --trunk --branches --leaves --up
	
	unset -f reset_module -f reset_parse
}

commit() {
	local SHOW_HELP=false
	local MESSAGE=""
	local OPTIONS="--trunk --branches --leaves"

	commit_parse() {
		local -n show_help_ref=$1
		local -n message_ref=$2
		local -n options_ref=$3
		shift 3

		# dir should normally have been declared globally but in case it hasn't
		if [ -z "$dir" ] ; then
			dir="."
		fi

		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				-m | --message)
					if [[ -n "$2" && "$2" != -* ]]; then
						message_ref="$2"
						shift 2
					else
						echo "Error: -m requires a commit message."
						exit 1
					fi
					;;
				--trunk)
					if [[ ! $options_ref =~ "--trunk" ]]; then
						options_ref="${options_ref} --trunk"
					fi
					shift
					;;
				--no-trunk)
					options_ref=$(echo "${options_ref}" | sed 's/--trunk//g')
					shift
					;;
				--branches)
					if [[ ! $options_ref =~ "--branches" ]]; then
						options_ref="${options_ref} --branches"
					fi
					shift
					;;
				--no-branch)
					options_ref=$(echo "${options_ref}" | sed 's/--branches//g')
					shift
					;;
				--leaves)
					if [[ ! $options_ref =~ "--leaves" ]]; then
						options_ref="${options_ref} --leaves"
					fi
					shift
					;;
				--no-leaves)
					options_ref=$(echo "${options_ref}" | sed 's/--leaves//g')
					shift
				;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
		# Remove any leading or trailing whitespace
		options_ref=$(echo "$options_ref" | xargs)
	}

	commit_module(){
		local dir="$1"
		local path="$2"
		local name="$3"

		echo_colored "$path commit" "32" #green
		git -C "$path" commit -m "$MESSAGE"
	}

	commit_parse SHOW_HELP MESSAGE OPTIONS "${@}"
	if $SHOW_HELP; then
		commit_help
		exit 1
	fi

	if [ -z "$MESSAGE" ]; then
		echo "Error: Commit message is required. Use -m <message> to provide a commit message."
		exit 1
	fi

	climb commit_module "$OPTIONS" --up

	unset -f commit_module -f commit_parse
}

grow() {
	local SHOW_HELP=false
	local MESSAGE=""
	local MODULE=false
	local NOMODULE=false
	local ALL=false
	
	
	grow_parse() {
		local -n show_help_ref=$1
		local -n message_ref=$2
		local -n module_ref=$3
		local -n all_ref=$4
		local -n nomodule_ref=$5
		shift 5
		#dir should normally have been declared globally but in case it asn't
		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				-m | --message)
					if [[ -n "$2" && "$2" != -* ]]; then
						message_ref="$2"
						shift 2
					else
						echo "Error: -m requires a commit message."
						exit 1
					fi
					;;
				--module)
					module_ref=true
					shift
					;;
				-a | --all)
					all_ref=true
					shift
					;;
				--no-module)
					nomodule_ref=true
					shift
					;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
	}
	
	add_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		git -C "$dir" add --all
	}
	
	grow_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		
		echo_colored "$dir grow" "32" #green
		if $MODULE ; then
			git -C "$path" commit -m "$MESSAGE"
			git -C "$dir" add name
		elif $NOMODULE ; then
			git -C "$path" commit -m "$MESSAGE"
			if ! $ISTRUNK ; then
				git -C "$dir" reset name
			fi
		else #ALL
			git -C "$path" add --all
			git -C "$path" commit -m "$MESSAGE"
		fi
	}
	
	grow_parse SHOW_HELP MESSAGE MODULE ALL NOMODULE "${@}"
	if $SHOW_HELP; then
		grow_help
		exit 1
	fi
	
	if [ -z "$MESSAGE" ]; then
		echo "Error: Commit message is required. Use -m <message> to provide a commit message."
		exit 1
	fi
	
	if $MODULE ; then
		climb grow_module --branches --leaves --down
	elif $NOMODULE ; then
		climb add_module --trunk --branches  --leaves --up
		climb grow_module --trunk --branches --leaves --down
	else #ALL
		climb grow_module --trunk --branches --leaves --down
	fi
	
	
	unset -f grow_module -f grow_parse -f add_module
}

mute() {
	local SHOW_HELP=false
	local RED='31'
	local GREEN='32'
	local UNDO=false
	local COMMAN=""
	local MESSAGE=""
	local SHOW=false
	local CMDARGS=()
	
	mute_parse() {
		local -n show_help_ref=$1
		local -n undo_ref=$2
		local -n show_ref=$3
		local -n cmd_args_ref=$4

		shift 4

		if [ -z "$dir" ] ; then
			dir="."
		fi
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				--undo)
					undo_ref=true
					shift
					;;
				--show)
					show_ref=true
					shift
					;;
				--*)
					cmd_args_ref+=("$1")
					shift
					;;
				-*)
					cmd_args_ref+=("$1")
					shift
					;;
				*)
					echo "Unknown option: $1"
					exit 1
					;;
			esac
		done
	}
	
	mute_cmd() {
		git -C "$path" remote set-url --push origin no_push
	}
	
	undo_cmd() {
		pullurl="$(git -C "$path" remote get-url origin)"
		git -C "$path" remote set-url --push origin "$pullurl"
	}
	
	show_cmd() {
		#pullurl="$(git -C "$path" remote get-url origin)"
		#echo "pull : $pullurl"
		pushurl="$(git -C "$path" remote get-url origin --push)"
		echo "$pushurl"
	}
	
	mute_parse SHOW_HELP UNDO SHOW CMDARGS "${@}"
	if $SHOW_HELP; then
		mute_help
		exit 1
	fi
	
	if $UNDO; then
		COMMAND=undo_cmd
		MESSAGE="Which module do we unmute ?"
	elif $SHOW; then
		COMMAND=show_cmd
		MESSAGE="Showing push url."
	else
		COMMAND=mute_cmd
		MESSAGE="Which module do we mute ?"	
	fi 
	
	if ! $SHOW; then
		gitmod prompt $COMMAND -m "$MESSAGE" "${CMDARGS[@]}"
	else
		gitmod prompt $COMMAND -m "$MESSAGE" --yes "${CMDARGS[@]}"
	fi
	
	unset -f mute_tree -f mute_parse  -f mute_cmd -f undo_cmd -f show_cmd
}

gitmod "${@}"

)

