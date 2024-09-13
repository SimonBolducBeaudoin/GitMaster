#!/bin/bash
git-monkey ()(
# A big function using a subshell to separate scopes
# This helps with exit 1 handling (just use error instead of error)
# and makes all function and variables local
WHITE='0'
RED='31'
GREEN='32'
YELLOW='33'
CYAN='36'

declare -i MAXDEPTH=5
declare -i DEPTH=0

ISTRUNK=false
ISLEAVES=false

SUBMODULE_NAME='^[[:space:]]*\\[submodule[[:space:]]*\"(.+)\"[[:space:]]*\\][[:space:]]*$'
TRIM='^[[:space:]]+|[[:space:]]+$'
COMMENT='^[[:space:]]*#'

git-monkey_help() {
local help_message="
An extension of git for projects with git modules.

Usage: git-monkey [-h | --help] [-C <path>] <command> [<args>]

These are the supported commands for now :
  tree   prints the tree of modules
  climb       Helps to recursively iterate over modules
  grow        Add and commit from leaves to trunk
  status 	  prints short status of modules	
  checkout    Checkouts the branches defined in .gitmodules (trunk first)
  pull        pulls and stop at conflicts (trunk first)
  push 	      push and stop at git push errors (leaves first)
  add         Adds files to the index for each module (leaves first)
  reset       git reset all modules
  commit      Record changes to the rep4Zository for each module and stops at conflicts (leaves first)

Example usage:
  # The tree of modules as a trunk branches and leaves
  git-monkey tree
  
  # climb is similar but more powerful than git submodule --foreach
  git-monkey climb --help
  
  # Resolving detached head states for each modules
  git-monkey checkout -C /path/to/repo 
  
  # Getting updates
  git-monkey pull --rebase
  
  # Only committing commit pointers (aka the state of each module)
  git-monkey add -C /path/to/repo --modules
  git-monkey commit -m 'Updating modules'
	"
	echo "$help_message"
}

climb_help() {
local help_message="
A helper to iterate over a tree of git modules.
Climbing up or down the tree of git modules calling <func> every step of the way.

Usage: git-monkey [...] climb <func> [options]

Options:
	  --leaves                Execute on leaves (default is false)
	  --branches              Execute on leaves (default is false)
	  --trunk                 Execute on trunk  (default is false)
	  --up                    Climb up the tree (default)
	  --down                  Climb down the tree
	  --help                  Display this help message

Help:
To see what trunk, branches, and leaves are, call
	git-monkey tree.
When using --trunk, func will be called on the trunk using \$path=\$dir (i.e. trunk has no parents).

Examples:

	# Use git -C $dir/$path to call git in the current submodule (inside the current module)
	dummy() {
		# Climb will recursively call this function in each module
		dir='\$1'    # \$1 is the directory of that module
		path='\$2'   # \$2 is the path towards the current submodule (inside module)
		name='\$3'   # \$3 is the name of the current submodule (inside module)
		echo ' Module \$3 in directory \$1 '
		git -C '$dir/$path' log --all --decorate --oneline --graph -n1
	}
	git-monkey climb dummy --trunk --leaves --down

	# use get_module_key '.../gitmodules' '\$name' 'key'
	# to read the current module's .gitmodules file
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
	git-monkey climb say_url --trunk --branches --leaves --up
	"
	echo "$help_message"
}

monkey_catch_help() {
    local help_message="
Usage: monkey_catch [options] <command>

Options:
  -h, --help       Show this help message and exit.
  -p, --pad        Set padding before the formatted text. Example: -p 10
  -c, --color      Set text color using ANSI color codes. Example: -c 32 (green)
  --maxpad         Set the maximum padding value. Example: --maxpad 50

Description:
  Executes a command and prints its output with optional padding and color.
  The command's output is padded and colored according to the specified options.

Examples:
  monkey_catch -p 5 -c 31 --maxpad 40 'echo Error: %s' 'File not found'
  monkey_catch --maxpad 30 'ls -l'
"

    echo "$help_message"
}


plant_help() {
local help_message="
Plants a new (git) worktree based on an existing branch of the project,
and prompts the user to setup all the .gitmodules files for that new worktree
and initialize all submodules during this process.

In the end the user as a new worktree that is all setup for that branch.
Ex: if you'd want a worktree that contains your devel branch (and all its devel submodules).
 
Usage: git-monkey [...] plant <branch> [options]

Options:
	  --path		The default path is '..' and the worktree gets named '../projectname_branch' automatically
	  --help        Display this help message
" 
echo "$help_message"
}

checkout_help() {
local help_message="
For each module in .gitmodules gets the value of branch
and then call 'git checkout branch' for that module.
It doesn't checkout the trunk.
The checkout order is then branches-->leaves

Usage: git-monkey [...] checkout"
echo "$help_message"
}

pull_help() {
local help_message="
For each module in .gitmodules gets the value of update (merge or rebase)	
to determine which type of pull it should do.
If conflicts occurs during a pull it stops there (doesn't pull the whole project).
You must then solve the conflict for that specific project and git-monkey pull again.
	
The pull order is then trunk-->branches-->leaves

Usage: git-monkey [...] pull [options]

Options:
      -r | --rebase 		 forces pull --rebase for all module
      --merge | --no-rebase forces pull --no-rebase for all module"
echo "$help_message"
}

push_help() {
local help_message="
Pushes modules one by one (leaves-->branches-->trunk)
If an erro occurs it stops there (doesn't push the whole project).
You must then solve the problem for that module and git-monkey push again.

Usage: git-monkey [...] pull [options]

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
git-monkey add followed by git mod commit would have the
same effect as commit the whole local super repo.
If you which to have this effect use  git-monkey grow,
which add and commits leaves before add and commit branches.

Usage: git-monkey [...] add [options] 
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

Usage: git-monkey [...] reset "
echo "$help_message"
}

commit_help() {
local help_message="
Commit all staged changes in all modules with the same message.

Usage: git-monkey [...] commit -m <message> [options]
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

Usage: git-monkey [...] grow -m <message> [options] 

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

Usage: git-monkey [...] mute [options]

Options :
		--undo 			Reset the push url to be equal to the pull url.
		--show 			Show what is the push url.
"
echo "$help_message"
}

status_help() {
local help_message="
Display a short status for each modules

Usage: git-monkey [...] status
"
echo "$help_message"
}

branch_help() {
local help_message="
Display a the complete list of branches for each modules

Usage: git-monkey [...] branch
"
echo "$help_message"
}

prompt_help() {
local help_message="
Promts the user (Y/N) one module at a time to trigger some given action (func).
 
Usage: git-monkey [...] prompt func [options]" 
echo "$help_message"
}


monkey_catch() {
    local SHOW_HELP=false
    local PADDING=0
    local COLOR=0
    local MAX_PADDING=50
    local COMMANDS=()
    local OUTPUT=""
    local EXTRA_LINE=false
	local SHOW_COMMAND=false
	local CMDOUT=""

    monkey_catch_parse() {
        local -n show_help_ref=$1
        local -n pad_ref=$2
        local -n clr_ref=$3
        local -n max_pad_ref=$4
        local -n cmds_ref=$5
        local -n extra_line_ref=$6
        local -n showcmd_ref=$7

        shift 7

        while (( "$#" )); do
            case "$1" in
                -h|--help)
                    show_help_ref=true
                    shift
                    ;;
                -p|--pad)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        pad_ref="$2"
                        shift 2
                    else
                        error -m "-p|--pad requires padding value."
                    fi
                    ;;
                -c|--color)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        clr_ref="$2"
                        shift 2
                    else
                        error -m "-c|--color requires an ANSI color number."
                    fi
                    ;;
                --maxpad)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        max_pad_ref="$2"
                        shift 2
                    else
                        error -m "--maxpad requires a maximum padding value."
                    fi
                    ;;
                -n|--extra-line)
                    extra_line_ref=true
                    shift
                    ;;
				--cmd|--show_command)
                    showcmd_ref=true
                    shift
                    ;;
                *)
                    cmds_ref+=("$1")
                    shift 
                    ;;
            esac
        done
    }

    monkey_catch_parse SHOW_HELP PADDING COLOR MAX_PADDING COMMANDS EXTRA_LINE SHOW_COMMAND "$@"

    if $SHOW_HELP ; then
        monkey_catch_help
        exit 1
    fi

    if (( PADDING > MAX_PADDING )); then
        PADDING=$MAX_PADDING
    fi
    if (( PADDING < 0 )); then
        PADDING=0
    fi
	
	if $SHOW_COMMAND ; then
        CMDOUT="$(printf '%s' "${COMMANDS[@]}")"
		CMDOUT=$(printf "%s" "$CMDOUT" | awk -v pad="$PADDING" '{ printf "%*s%s\n", pad, "", $0 }')
		printf "\e[${COLOR}m%s\e[0m\n" "$CMDOUT"
    fi
    OUTPUT="$("${COMMANDS[@]}" 2>&1)"
    OUTPUT=$(printf "%s" "$OUTPUT" | awk -v pad="$PADDING" '{ printf "%*s%s\n", pad, "", $0 }')

    if $EXTRA_LINE; then
        printf "\e[${COLOR}m%s\e[0m\n" "$OUTPUT"
    else
        printf "\e[${COLOR}m%s\e[0m" "$OUTPUT"
    fi

    unset -f monkey_catch_parse
}
	

monkey_say() {
    monkey_catch printf "$@"
}

error() {
    local MESSAGE=""               
	local OUT="GIT-MONKEY ERROR:"

    error_parse() {
        local -n message_ref=$1
        shift 1

        while (( "$#" )); do
            case "$1" in
                -m|--message)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        message_ref="$2"
                        shift 2
                    else
                        return 1
                    fi
                    ;;
            esac
        done
    }

    error_parse MESSAGE "$@"

	if [ -n "$MESSAGE" ] ; then
		OUT+="\n\n"
		OUT+="$MESSAGE"
		OUT+="\n\n"
	fi
	
	local i
    local frame_count=${#FUNCNAME[@]}
	
	local max_file_name_length=0
    local max_func_name_length=0
	
	for ((i=1; i<frame_count; i++)); do
        local file_name="${BASH_SOURCE[$i]}"
        local func_name="${FUNCNAME[$i]}"

        # Update maximum lengths
        [[ ${#file_name} -gt max_file_name_length ]] && max_file_name_length=${#file_name}
        [[ ${#func_name} -gt max_func_name_length ]] && max_func_name_length=${#func_name}
    done
	
	local file_name_width=$((max_file_name_length + 1))
    local func_name_width=$((max_func_name_length + 1))
	
	(( file_name_width < 9 )) && file_name_width=9
    (( func_name_width < 13 )) && func_name_width=13
	
	# OUT+="\n"
	# OUT+="Error trace:"
    OUT+="$(printf "\n%-${file_name_width}s %-${func_name_width}s %s" "File Name" "Function Name" "Line (Not reliable)")\n"
    OUT+="$(printf "%-${file_name_width}s %-${func_name_width}s %s" "---------" "-------------" "----")\n"

    for ((i=1; i<frame_count; i++)); do
        OUT+="$(printf "%-${file_name_width}s %-${func_name_width}s %s" "${BASH_SOURCE[$i]}" "${FUNCNAME[$i]}" "${BASH_LINENO[$((i-1))]}")\n"
    done
	
    printf "\e[31m%s\e[0m\n" "$(printf "$OUT")"
    exit 1
}

yes_no() {
    local message=""
    local answer=""
    local default
    local PADDING=0
    local MAX_PADDING=50

    get_yes_no_parse() {
        local -n msg_ref=$1
        local -n def_ref=$2
        local -n pad_ref=$3
        local -n max_pad_ref=$4

        shift 4

        while (( "$#" )); do
            case "$1" in
                -d|--default)
                    if [[ "$2" =~ ^[YyNn]$ ]]; then
                        def_ref="$2"
                        shift 2
                    else
                        error -m "Invalid default value. Use 'Y' or 'N'."
                    fi
                    ;;
                -m|--message)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        msg_ref="$2"
                        shift 2
                    else
                        error -m "-m|--message requires a message."
                    fi
                    ;;
                -p|--pad)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        pad_ref="$2"
                        shift 2
                    else
                        error -m "-p|--pad requires padding value."
                    fi
                    ;;
                --maxpad)
                    if [[ -n "$2" && "$2" != -* ]]; then
                        max_pad_ref="$2"
                        shift 2
                    else
                        error -m "--maxpad requires a maximum padding value."
                    fi
                    ;;
                *)
                    error -m "Unknown option: $1" 
                    ;;
            esac
        done
    }

    get_yes_no_parse message default PADDING MAX_PADDING "$@"

    if (( PADDING > MAX_PADDING )); then
        PADDING=$MAX_PADDING
    fi
    if (( PADDING < 0 )); then
        PADDING=0
    fi

	message="$(printf "%*s${message}" "$PADDING")"
    while true; do
        if [ -n "$default" ]; then
            read -rp "$message (Y/N) [${default}]: " answer
            answer="${answer:-$default}"
        else
            read -rp "$message (Y/N): " answer
        fi

        case "$answer" in
            [Yy]* ) echo true; return 0;;
            [Nn]* ) echo false; return 0;;
            * ) ;;
        esac
    done
}


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

set_module_key() {
    local file="$1"
    local name="$2"
    local key="$3"
    local new_value="$4"
    
    local temp_file=$(mktemp)
    
    awk_prgm='
    BEGIN { in_table = 0; found_key = 0 }
    function trim(str) { gsub(trim_reg, "", str); return str }
    match($0, table_head, matches) {
        if (matches[1] == table_name) {
            in_table = 1
        } else if (in_table == 1) {
            if (found_key == 0) {
                print "\t" key " = " new_value
            }
            in_table = 0
        }
    }
    {
        if (in_table && trim($1) == key) {
            found_key = 1
            sub($2, new_value)
            print $1 "= " $2
        } else {
            print $0
        }
    }
    END {
        if (in_table && found_key == 0) {
            print "\t" key " = " new_value
        }
    }
    '
    
    awk -F= -v table_name="$name" -v key="$key" -v new_value="$new_value" -v table_head="$SUBMODULE_NAME" -v trim_reg="$TRIM" "$awk_prgm" "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

git-monkey() {
	local dir="."
	local command=""
	local CMDARGS=()
	local PRIVATEMODE=false
	local DEPRECATEDMODE=false
		
	git-monkey_parse() {
		local -n dir_ref=$1
		local -n command_ref=$2
		local -n cmd_args_ref=$3
		local -n privatemode_ref=$4
		local -n deprecatedmode_ref=$5
		
		shift 5

		local public_commands=("climb" "tree" "plant" "grow" "status" "prompt" "checkout" "pull" "push" "add" "reset" "commit" "mute" "DOS2UNIX")
		local private_commands=("monkey_catch" "monkey_say" "error" "yes_no" "get_module_names" "get_module_key" "set_module_key")
		local deprecated_commands=("spawn" "branch")

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
				--private)
					privatemode_ref=true
					shift
					;;
				--deprecated)
					deprecatedmode_ref=true
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
						if [[ " ${public_commands[@]} " =~ " $1 " ]]; then
							command_ref="$1"
						elif [[ " ${private_commands[@]} " =~ " $1 " && "$privatemode_ref" == true ]]; then
							command_ref="$1"
						elif [[ " ${deprecated_commands[@]} " =~ " $1 " && "$deprecatedmode_ref" == true ]]; then
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

	git-monkey_parse dir command CMDARGS PRIVATEMODE DEPRECATEDMODE "$@"

	if [ -z "$command" ] ; then
	   git-monkey_help
	   exit 1
	fi
	
	if [ PRIVATEMODE == true ]; then
	   monkey_say "######################\n PRIVATE MODE: \n ######################" -n --color "$CYAN"
	fi
	
	if [ PRIVATEMODE == true ]; then
	   monkey_say "######################\n DEPRECATED MODE: \n ######################" -n --color "$RED"
	fi
	
	# Execute the command with the collected flags
	"$command" "${CMDARGS[@]}"
	
	unset -f git-monkey_parse
}

spawn() {
	local SHOW_HELP=false
	
	parse() {
		local -n show_help_ref=$1

		shift 1
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
					error -m "Unknown option: $1"
					;;
			esac
		done
	}
	
	parse SHOW_HELP "${@}"
	if $SHOW_HELP; then
		status_help
		exit 1
	fi
	
	git -C "$dir" submodule update --init --recursive
	git-monkey checkout
	git-monkey tree
	
	unset -f parse
}


climb() {
	local func=""
	local LEAVES=false
	local BRANCHES=false
	local TRUNK=false
	local UPWARD=true
	local SHOW_HELP=false
	local INITIALIZATION=false
	
	climb_parse() {
		local -n leaves_ref=$1
		local -n branches_ref=$2
		local -n trunk_ref=$3
		local -n upward_ref=$4
		local -n show_help_ref=$5
		local -n func_ref=$6
		local -n init_ref=$7
		
		local non_flag_args=0

		shift 7
		
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
				--init|--initialization)
					upward_ref=true
					init_ref=true
					shift
					;;
				--help)
					show_help_ref=true
					shift
					;;
				-*)
					error -m "Unknown option: $1"
					;;
				*)
					non_flag_args=$((non_flag_args + 1))
					if [[ $non_flag_args -gt 1 ]]; then
						error -m "Unknown option: $1"
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
		local branching_up=false	
		
		
		 (( DEPTH += 1 ))
		
		if (( DEPTH > MAXDEPTH )); then
			error -m "Max depth reached in $dir"
		fi
		
		# On the way up
		if (( DEPTH > 0 ))	&& $UPWARD && [[ $INITIALIZATION == true || -f "$dir/$path/.gitmodules" ]] && $BRANCHES ; then
			"$func" "$dir" "$path" "$module"
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
		elif $LEAVES && (( DEPTH < MAXDEPTH )) && [ $INITIALIZATION == false ]; then
			ISLEAVES=true
		   "$func" "$dir" "$path" "$module"
			ISLEAVES=false			
			
		fi
		
		# On the way down
		if (( DEPTH > 0 ))	&& ! $UPWARD && [ -f "$dir/$path/.gitmodules" ] && $BRANCHES ; then
			"$func" "$dir" "$path" "$module"	
		fi
		
		(( DEPTH -= 1 ))
	}
	
	climb_parse LEAVES BRANCHES TRUNK UPWARD SHOW_HELP func INITIALIZATION "${@}"
		
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
						error -m "-m requires a message."
					fi
					;;
				-y | --yes)
					yall_ref=true
					shift
					;;
				-*)
					error -m "Unknown option: $1"
					;;
				*)
					non_flag_args=$((non_flag_args + 1))
					if [[ $non_flag_args -gt 1 ]]; then
						error -m "Unknown option: $1"
					fi
					func_ref="$1"
					shift
					;;
			esac
		done
	}
	
	prompt_tree(){
		local dir="$1"
		local path="$2"
		local name="$3"
		local answer=false
		local message=""
		local padding
		
		local -i PAD=$((DEPTH * 4))
		
		current_branch=$(git -C "$dir/$path" rev-parse --abbrev-ref HEAD)
		if $ISTRUNK ; then
			repo_path=$(git -C "$dir/$path" rev-parse --show-toplevel)
			repo_name=$(basename "$repo_path")	
			monkey_say "${repo_name} ($current_branch)" -n --pad "$PAD" --color "$RED"
		elif $ISLEAVES ; then
			monkey_say "${indent}└── ${name} ($current_branch)" -n --pad "$PAD" --color "$GREEN"
		else 
			monkey_say "${indent}└── ${name} ($current_branch)" -n --pad "$PAD" --color "$YELLOW"
		fi
				
		if $YALL ; then
			answer=true
		else
			answer="$(yes_no -d N --pad "$PAD")"
		fi
		
		if $answer ; then
			monkey_catch -n --pad "$((PAD+4))" "$FUNC" "$dir" "$path" "$name"
		fi
		
	}
	
	prompt_parse SHOW_HELP MESSAGE FUNC YALL "${@}"
	
	if $SHOW_HELP; then
		prompt_help
		exit 1
	fi
	
	if [ -z "$FUNC" ]; then
		error -m "No function given to prompt. Nothing to do." 
	fi
	
	printf "$MESSAGE \n" 
	git-monkey climb prompt_tree --trunk --branches --leaves --up
	
	unset -f prompt_tree -f prompt_parse
}

plant() {
	local SHOW_HELP=false
	local BRANCH=""
	local NEWTREEPATH=".."
	local LASTOUTPUT=""
	local answer=''
	
	local non_flag_args=0
	
	plant_parse() {
		local -n show_help_ref=$1
		local -n branch_ref=$2
		local -n newtreepath_ref=$3
		
		shift 3
				
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				--path)
					if [[ -n "$2" && "$2" != -* ]]; then
						newtreepath_ref="$2"
						shift 2
					else
						error -m "Error: No paths given after --path."
					fi
					;;
				-*)
					error -m "Unknown option: $1"
					;;
				*)
					non_flag_args=$((non_flag_args + 1))
					if [[ $non_flag_args -gt 1 ]]; then
						error -m "Unknown option: $1"
					fi
					branch_ref="$1"
					shift
					;;
			esac
		done
	}
	
	init_module(){
		local dir="$1"
		local path="$2"
		local -i PAD="$3"
		local color="$4"
		#echo ""
		monkey_say -n --pad "$((PAD+4))" --color "$CYAN" "git -C $dir submodule update --init $path"
		monkey_catch -n --pad "$((PAD+4))" --color "$WHITE" git -C "$dir" submodule update --init "$path"
		echo ""
		if [ "$?" != 0 ]; then
			error -m "Initialization failed."
		fi		
	}
	
	set_branch() {
	# Display available branches
	# Ask for which branch to switch to
	# Try to checkout the branch
	# Check if the checkout was successful
	# If sucess then modifies the .gitmodules to reflect that choice
		local dir="$1"
		local path="$2"
		local name="$3"
		local padding="$4"
		local color="$5"

		monkey_say "Availables branches : " -n --pad "$padding" --color "${color}"
		
		mapfile -t branches_array < <(git -C "$dir/$path" branch --all)
		for branch in "${branches_array[@]}"; do
			monkey_say "${branch}" -n --pad "$padding" --color "$WHITE"
		done

		while true; do
			monkey_say "Enter a branch name to checkout: " --pad "$padding" --color "${color}"
			read branch_name
		
			git -C "$dir/$path" checkout "$branch_name" > /dev/null 2>&1

			if [ $? -eq 0 ]; then
				monkey_say "Switched to branch '$branch_name'." -n --pad "$padding" --color "${color}"
				break
			else
				monkey_say "Branch '$branch_name' does not exist or checkout failed.\nPlease try again." -n --pad "$padding" --color "${color}"
			fi
		done
		
		set_module_key "$dir/.gitmodules" "$name" "branch" "$branch_name"
		
		monkey_say "(Updated) .gitmodules with $name.branch = $branch_name" -n --pad "$padding" --color "${color}"
		echo ""
	}
	
	plant_tree(){
		local dir="$1"
		local path="$2"
		local name="$3"
		local answer=''
		local -i max_length=50
		local -i PAD=$((DEPTH*4))
		if $ISTRUNK ; then
			current_branch=$(git -C "$dir/$path" rev-parse --abbrev-ref HEAD)
			repo_path=$(git -C "$dir/$path" rev-parse --show-toplevel)
			repo_name=$(basename "$repo_path")
			monkey_say "${repo_name} ($current_branch)" -n --pad "$PAD" --color "$RED"
		else
			branch=$(get_module_key "$dir/.gitmodules" "$name" "branch")
			if [ -n "$branch" ]; then
				message="└── ${name} () [$branch]"
			else 
				message="└── ${name} () []"
			fi
			monkey_say "${message}" -n --pad "$PAD" --color "$CYAN"
			
			init_module "$dir" "$path" "$PAD" "$WHITE"	
			set_branch "$dir" "$path" "$name" "$((PAD+4))" "$WHITE"
		fi	
	}
	
	plant_parse SHOW_HELP BRANCH NEWTREEPATH "${@}"
	
	if $SHOW_HELP; then
		plant_help
		exit 1
	fi
	
	repo_path=$(git -C "$dir" rev-parse --show-toplevel)
	repo_name=$(basename "$repo_path")
	
	local worktree_path="$dir/$NEWTREEPATH/${repo_name}_$BRANCH"
		
	answer="$(yes_no -m "Create new $BRANCH worktree ?"  -d Y )"
	if $answer ; then
		monkey_say "Planting branch '$BRANCH' at location '$worktree_path' " -n --color "$CYAN"
		LASTOUTPUT="$(git worktree add "$worktree_path" "$BRANCH" 2>&1)"
		if [ "$?" != 0 ] ; then
			error -m "$LASTOUTPUT" 
		fi
	fi
	
	
	cd "$worktree_path" 
	dir="." 
	
	answer="$(yes_no -m "Initialize and setup submodules ?"  -d Y )"
	if $answer ; then
		git-monkey climb plant_tree --init --trunk --branches --leaves --up
	fi
	
	answer="$(yes_no -m "Are there submodules's to protect from being pushed/mutes ? "  -d Y )"
	if $answer ; then
		git-monkey mute
	fi
	
	monkey_say "INITIALIZATION DONE ! " -n --color "$CYAN" 
	git-monkey tree
	
	answer="$(yes_no -m "Commit changes ? "  -d N )"
	if $answer ; then
		git-monkey DOS2UNIX
		git-monkey grow -m "$BRANCH worktree initialization."
	fi
	
	answer="$(yes_no -m "Push ? "  -d N )"
	if $answer ; then
		git-monkey push
	fi
	
	unset -f plant_tree -f plant_parse -f set_branch -f init_module
}

tree() {
	local SHOW_HELP=false
	local DOWN=false
	local SEP="└──"
	
	tree_parse() {
		local -n show_help_ref=$1
		local -n down_ref=$2

		shift 2
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				--down)
					down_ref=true
					shift
					;;
				*)
					error -m "Unknown option: $1"
					;;
			esac
		done
	}
	
	draw_tree(){
		local depth=$DEPTH #defined in climb
		local dir="$1"
		local path="$2"
		local name="$3"
		
		local branch=""
		
		local -i PAD=$((DEPTH * 4))
		
		current_branch=$(git -C "$dir/$path" rev-parse --abbrev-ref HEAD)
		if $ISTRUNK ; then
			repo_path=$(git -C "$dir/$path" rev-parse --show-toplevel)
			repo_name=$(basename "$repo_path")
			echo ""
			echo "Legend : "
			echo "    (HEAD) as returned by git rev-parse --abbrev-ref HEAD"
			echo "    [branch] as declared in .gitmodules"
			echo ""
			monkey_say "${repo_name} ($current_branch)" -n --pad "$PAD" --color "$RED"
		elif $ISLEAVES ; then
			branch=$(get_module_key "$dir/.gitmodules" "$name" "branch")
			if [ -n "$branch" ]; then
			monkey_say "$SEP ${name} ($current_branch) [$branch]" -n --pad "$PAD" --color "$GREEN"
			else 
			monkey_say "$SEP ${name} ($current_branch) []" -n --pad "$PAD" --color "$GREEN"
			fi
		else 
			monkey_say "$SEP ${name} ($current_branch)" -n --pad "$PAD"
		fi
		
	}
	
	tree_parse SHOW_HELP DOWN "${@}"
	if $SHOW_HELP; then
		tree_help
		exit 1
	fi
	
		
	if ! $DOWN; then
		git-monkey climb draw_tree --trunk --branches --leaves --up
	else
		SEP="┌──"
		git-monkey climb draw_tree --trunk --branches --leaves --down
	fi
	
	unset -f draw_tree -f tree_help -f tree_parse
}


checkout() {
	local SHOW_HELP=false
	
	checkout_parse() {
		local -n show_help_ref=$1
		shift 1

		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
					error -m "Unknown option: $1"
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
			monkey_say "$path checkout $branch" -n --color "32" #green
			git -C "$dir/$path" checkout "$branch" 
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
					error -m "Unknown option: $1"
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
		
		monkey_say "$path pull " -n --color "32" #green
		branch=$(get_module_key "$dir/.gitmodules" "$name" "branch")
		update=$(get_module_key "$dir/.gitmodules" "$name" "update")
		
		if [ -n "$branch" ]; then 
			git -C "$dir/$path" checkout "$branch" --quiet
		fi
		
		if $FORCE_REBASE ; then
			pull_type="--rebase"
		elif $FORCE_MERGE ; then
			pull_type="--no-rebase"
		elif [ -n "$update" ]; then
			pull_type=$(get_module_key "$dir/.gitmodules" "$name" "update")
		fi
		
		# only pull module for which branch is defined
		# This sorta inforce the use of .gitmodules branch and update.
		if [ -n "$branch" ]; then 
			git -C "$dir/$path" pull "$pull_type"
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

push() {
	local SHOW_HELP=false
	local FORCE=false
	
	push_parse() {
		local -n show_help_ref=$1
		local -n force_ref=$2
		shift 2
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				--force)
					force_ref=true
					shift
					;;
				*)
					error -m "Unknown option: $1"
					;;
			esac
		done
	}
	push_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		local LASTOUTPUT=""
		
		monkey_say "$path push " -n --color "32" #green
		
		# will return "no_push" when repo as been set to mute
		pushurl="$(git -C "$dir/$path" remote get-url origin --push)"
		
		if [ -z "$pushurl" ] || [ "$pushurl" == "no_push" ] ; then
			echo "skip"
			return 0 
		fi
		
		if [ "$FORCE" != true ] ; then
			LASTOUTPUT="$(git -C "$dir/$path" push 2>&1)"
		elif [ "$FORCE" == true ] ; then
			LASTOUTPUT="$(git -C "$dir/$path" push --force 2>&1)"
		fi
		
		if [ "$?" != 0 ] ; then
			error -m "$LASTOUTPUT"
		else 
			monkey_say --color "$CYAN" "$LASTOUTPUT " -n
		fi	
	}
	
	push_parse SHOW_HELP FORCE "${@}"
	if $SHOW_HELP; then
		push_help
		exit 1
	fi
	
	climb push_module --trunk --branches --leaves --up
	
	unset -f push_module -f push_parse
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
					error -m "Unknown option: $1"
					;;
			esac
		done
	}
	add_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		
		monkey_say "$dir add " -n --color "32" #green
		
		if $MODULE ; then
			git -C "$dir" add name
		elif $NOMODULE ; then
			git -C "$dir/$path" add --all 
			if ! $ISTRUNK ; then
				git -C "$dir" reset name 
			fi
		else #ALL
			git -C "$dir/$path" add --all
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
		monkey_say "$path reset " -n --color "32" #green
		git -C "$dir/$path" reset
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
						error -m "-m requires a commit message."
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
					error -m "Unknown option: $1"
					;;
			esac
		done
		# Remove any leading or trailing whitespace
		options_ref=$(echo "$options_ref" | xargs)
	}

	commit_module(){
		local dir="$1"
		local dir="$1"
		local path="$2"
		local name="$3"

		monkey_say "$path commit " -n --color "32" #green
		git -C "$dir/$path" commit -m "$MESSAGE"
	}

	commit_parse SHOW_HELP MESSAGE OPTIONS "${@}"
	if $SHOW_HELP; then
		commit_help
		exit 1
	fi

	if [ -z "$MESSAGE" ]; then
		error -m "Commit message is required. Use -m <message> to provide a commit message."
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
						error -m "-m requires a commit message."
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
					error -m "Unknown option: $1"
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
		
		monkey_say "$dir grow " -n --color "32" #green
		if $MODULE ; then
			git -C "$dir/$path" commit -m "$MESSAGE"
			git -C "$dir" add name
		elif $NOMODULE ; then
			git -C "$dir/$path" commit -m "$MESSAGE"
			if ! $ISTRUNK ; then
				git -C "$dir" reset name
			fi
		else #ALL
			git -C "$dir/$path" add --all
			git -C "$dir/$path" commit -m "$MESSAGE"
		fi
	}
	
	grow_parse SHOW_HELP MESSAGE MODULE ALL NOMODULE "${@}"
	if $SHOW_HELP; then
		grow_help
		exit 1
	fi
	
	if [ -z "$MESSAGE" ]; then
		error -m "Commit message is required. Use -m <message> to provide a commit message."
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
					error -m "Unknown option: $1"
					;;
			esac
		done
	}
	
	mute_cmd() {
		git -C "$dir/$path" remote set-url --push origin no_push
	}
	
	undo_cmd() {
		pullurl="$(git -C "$dir/$path" remote get-url origin)"
		git -C "$dir/$path" remote set-url --push origin "$pullurl"
	}
	
	show_cmd() {
		#pullurl="$(git -C "$dir/$path" remote get-url origin)"
		#echo "pull : $pullurl"
		pushurl="$(git -C "$dir/$path" remote get-url origin --push)"
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
		git-monkey prompt $COMMAND -m "$MESSAGE" "${CMDARGS[@]}"
	else
		git-monkey prompt $COMMAND -m "$MESSAGE" --yes "${CMDARGS[@]}"
	fi
	
	unset -f mute_parse  -f mute_cmd -f undo_cmd -f show_cmd
}

status() {
	local SHOW_HELP=false
	
	parse() {
		local -n show_help_ref=$1
		shift 1

		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
					error -m "Unknown option: $1"
					;;
			esac
		done
	}
	
	command() {
		head_status="$(git -C "$1/$2" rev-parse --abbrev-ref HEAD 2>/dev/null)"
		if [[ "$head_status" == "HEAD" ]]; then
			printf "Detached HEAD"
			return 0
		fi
		
		status="$(git -C "$1/$2" status --short)"
		if [ -z "$status" ] ; then
			status="Up to date"
		fi
		printf "$status"
	}
	
	parse SHOW_HELP "${@}"
	if $SHOW_HELP; then
		status_help
		exit 1
	fi
	
	git-monkey prompt command --yes
	
	unset -f parse -f command
}

branch() {
	local SHOW_HELP=false
	
	parse() {
		local -n show_help_ref=$1

		shift 1


		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
					error -m "Unknown option: $1"
					;;
			esac
		done
	}
	
	command() {
		git -C "$1/$2" branch --all
	}
	
	parse SHOW_HELP "${@}"
	if $SHOW_HELP; then
		status_help
		exit 1
	fi
	
	git-monkey prompt command --yes
	
	unset -f parse -f command
}

DOS2UNIX() {
	command() {
		dos2unix "$1/.gitmodules"
	}
	
	git-monkey prompt command --yes
	
	unset -f command
}


git-monkey "${@}"

)

