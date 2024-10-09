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
SEP="└──"
declare -i XPAD=${#SEP}

ISSTART=false
ISTRUNK=false
ISBRANCH=false
ISLEAVES=false
ISEND=false

VERBOSE=false			 

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
Adda all changes that aren't specific to module pointers.

If you wish to commit module pointers use the 'grow' command.

Usage: git-monkey add [options]

Options:
   -f | --file <file>       Add changes from the specified file only
   -a | --all               Add all changes in the repository
   --help                   Display this help message
"
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
		-m | --message       commit message (mendatory) "
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

stash_help() {
local help_message="
Stash or pop all changes

Usage: git-monkey [...] stash [pop]
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


IGNORE_help() {
local help_message="
Add a line to all .gitignore at the same time.

If the line starts with a '!' it need to be escaped !

Usage: git-monkey [...] IGNORE <line to be added to .gitignore> " 
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
	local STATUS=""
	local SILENT=false
	local PROMPT=false
    local OK=()
	local EXCEPT=()			   

    monkey_catch_parse() {
        local -n show_help_ref=$1
        local -n pad_ref=$2
        local -n clr_ref=$3
        local -n max_pad_ref=$4
        local -n cmds_ref=$5
        local -n extra_line_ref=$6
        local -n showcmd_ref=$7
        local -n silent_ref=$8
		local -n prompt_ref=$9
		local -n ok_ref=${10}
		local -n except_ref=${11}						   

        shift 11

        while (( "$#" )); do
            # no command has been found yet
            if [[ -z "$cmds_ref" ]] ; then 
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
                        if [[ -n "$2" && "$2" != -* ]]; then
                            showcmd_ref="$2"
                            shift 2
                        else
                            error -m "--prompt true or false ?"
                        fi
                        ;;
                    --prompt)
                        if [[ -n "$2" && "$2" != -* ]]; then
                            prompt_ref="$2"
                            shift 2
                        else
                            error -m "--prompt true or false ?"
                        fi
                        ;;
                    --silent)
                        if [[ -n "$2" && "$2" != -* ]]; then
                            silent_ref="$2"
                            shift 2
                        else
                            error -m "--silent true or false ?"
                        fi
                        ;;
                    --ok)
                        shift
                        while (( "$#" )); do
                            if [[ -n "$1" && "$1" != -* ]]; then
                                ok_ref+=("$1")
                                shift
                            else
                                break
                            fi
                        done
                        ;;
					--except)
                        shift
                        while (( "$#" )); do
                            if [[ -n "$1" && "$1" != -* ]]; then
                                except_ref+=("$1")
                                shift
                            else
                                break
                            fi
                        done
                        ;;	  
                    -f|--func)
                        cmds_ref+=("$2")
                        shift 2
                        ;;
                    -*|--*)
                        error -m "monkey_catch received invalid flag/command : $1"
                        ;;
                esac
            else
                # All remaining arguments after -f func are treated as func's arguments
                cmds_ref+=("$@") 
                break
            fi
        done
    }

	core(){
		if (( PADDING > MAX_PADDING )); then
			PADDING=$MAX_PADDING
		fi
		if (( PADDING < 0 )); then
			PADDING=0
		fi

		if [[ $SHOW_COMMAND == true || $VERBOSE == true ]] ; then
			CMDOUT="$(printf '%s ' "${COMMANDS[@]}")"
			CMDOUT=$(printf "%s" "$CMDOUT" | awk -v pad="$PADDING" '{ printf "%*s%s\n", pad, "", $0 }')
			printf "\e[${COLOR}m%s\e[0m\n" "$CMDOUT"
		fi
		 
		local color="\033[${COLOR:-32}m"
		temp_file=$(mktemp)
		if [[ $SILENT == true ]] ; then
			# Only stdout to /dev/null
			 
			"${COMMANDS[@]}" > /dev/null 2> "temp_file"
			STATUS="$?"
		else
			"${COMMANDS[@]}" > >(tee /dev/null | awk -v pad="$PADDING" -v color="$color" '{ printf "%s%*s%s\033[0m\n", color, pad, "", $0 }') 2> "$temp_file"
			STATUS="$?"
		fi						  
		local SKIP=false
        if [[ -n "${OK[*]}" && "$STATUS " =~ "${OK[@]}" ]] ; then 
            SKIP=true
        fi
		local PASS=false
        if [[ -n "${EXCEPT[*]}" && "$STATUS " =~ "${EXCEPT[@]}" ]] ; then
			SKIP=true
            PASS=true
        fi
		
		if [[ $STATUS -ne 0 && "$SKIP" == false ]]; then
			error -m "$temp_file" --status "$STATUS"								 
		elif [[ $STATUS -ne 0 && "$PASS" == true ]]; then
			# This will not be padded properly ...
			printf "\e[${COLOR}m%s\e[0m\n" "$OUTPUT"
			return "$STATUS"										   			 
		fi
		rm -f "$temp_file" 
		
		# if $EXTRA_LINE; then
			# printf "\n"
		# fi
	}

    monkey_catch_parse SHOW_HELP PADDING COLOR MAX_PADDING COMMANDS EXTRA_LINE SHOW_COMMAND SILENT PROMPT OK EXCEPT "$@"

    if $SHOW_HELP ; then
        monkey_catch_help
        exit 1
    fi

	local answer=false
	if $PROMPT ; then
		answer="$(yes_no -d N --pad "$PADDING")"
		if $answer ; then
			core
		fi
	else
		core
	fi
	
    unset -f monkey_catch_parse -f core
}
	

monkey_say() {
	local save_verb=VERBOSE
	VERBOSE=false
    args=("$@")          
    monkey_catch "${args[@]:1}" --func printf "$1"
	VERBOSE=save_verb
}

error() {
    local MESSAGE=""               
	local OUT="GIT-MONKEY ERROR:"
	local -i EXITSTATUS=1

    error_parse() {
        local -n message_ref=$1
        local -n exitstatus_ref=$2
        shift 2

        while (( "$#" )); do
            case "$1" in
                -m|--message)
                    if [[ -n "$2" ]]; then
                        message_ref="$2"
                        shift 2
                    else
                        return 1
                    fi
                    ;;
				--status)
                    if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                        exitstatus_ref="$2"
                        shift 2
                    fi
                    ;;
            esac
        done
    }

    error_parse MESSAGE EXITSTATUS "$@"

	if [[ -n "$MESSAGE" ]] ; then
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
    exit "$EXITSTATUS"
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
        if [[ -n "$default" ]] ; then
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
    local SHOW_HELP=false
		
    git-monkey_parse() {
        local -n showhelp_ref=$1
        local -n dir_ref=$2
        local -n privatemode_ref=$3
        local -n deprecatedmode_ref=$4
        local -n command_ref=$5
        local -n cmd_args_ref=$6
        local -n verbose_ref=$7
		
        shift 7

        local public_commands=("spawn" "climb" "tree" "plant" "grow" "status" "stash" "checkout" "pull" "push" "add" "reset" "commit" "mute" "DOS2UNIX" "IGNORE" "RESTORE")
        local private_commands=("error" "monkey_catch" "monkey_say" "error" "yes_no" "get_module_names" "get_module_key" "set_module_key" "dummy")
        local deprecated_commands=("branch")

        while (( "$#" )); do
            # no command has been found yet
            if [[ -z "$command_ref" ]] ; then 
                case "$1" in
                    -C)                    
                        if [[ -n "$2" && "$2" != -* ]]; then
                        dir_ref="$2"
                        shift 2
                        else
                            error -m "git-monkey -C needs a directory"
                        fi    
                        ;;
                    --help|-h)
                        showhelp_ref=true
                        shift
                        ;;
                    --verbose)
                        verbose_ref=true
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
                    --*|-*)
                        error -m "git-monkey received invalid flag/command : $1"
                        ;;	
                    *)						
                        if [[ " ${public_commands[@]} " =~ " $1 " ]]; then
                            command_ref="$1"
                        elif [[ " ${private_commands[@]} " =~ " $1 " && "$privatemode_ref" == true ]]; then
                            command_ref="$1"
                        elif [[ " ${deprecated_commands[@]} " =~ " $1 " && "$deprecatedmode_ref" == true ]]; then
                            command_ref="$1"
                        else
                            error -m "git-monkey received invalid flag/command : $1"
                        fi
                        if [[ "$command_ref" == "reset" ]] ; then
                            # I'm avoiding collision with the reset function.
                            command_ref="reset_modules" 
                        fi
                        shift
                        ;;
                esac
            else
                # All remaining arguments are treated as command arguments
                cmd_args_ref+=("$@") 
                break
            fi
        done
    }
	
	# VERBOSE IS GLOBAL
	git-monkey_parse SHOW_HELP dir PRIVATEMODE DEPRECATEDMODE command CMDARGS VERBOSE "$@"

	if [[ -z "$command" ]] || $SHOW_HELP ; then
	   git-monkey_help
	   exit 1
	fi
	
	if [ PRIVATEMODE == true ]; then
	   monkey_say "######################\n PRIVATE MODE: \n ######################" -n --color "$CYAN"
	fi
	
	if [ DEPRECATEDMODE == true ]; then
	   monkey_say "######################\n DEPRECATED MODE: \n ######################" -n --color "$RED"
	fi
	
	# Execute the command with the collected flags
	"$command" "${CMDARGS[@]}"
	
	unset -f git-monkey_parse
}

climb() {
	local func=""
    local FUNCARGS=()
	local LEAVES=false
	local BRANCHES=false
	local TRUNK=false
	local BEGIN=false
	local END=false
	local UPWARD=true
	local SHOW_HELP=false
	local INITIALIZATION=false
	local SILENT=false
	local TREE=false
	local FLAT=false
	local PROMPT=false
	local SHOW_COMMAND=false
	local MESSAGE=""
	local -i MODULE_HEADER=0
	local path="."
    local NOT=() # Modules not to be executed on
    local OK=() # Errors that are ok to be skipped
	
	climb_parse() {
		local -n show_help_ref=$1
        local -n leaves_ref=$2
		local -n branches_ref=$3
		local -n trunk_ref=$4
		local -n upward_ref=$5
		local -n init_ref=$6
		local -n begin_ref=$7
		local -n end_ref=$8
		local -n silent_ref=$9
		local -n tree_ref=${10}
		local -n flat_ref=${11}
		local -n header_type_ref=${12}
		local -n prompt_ref=${13}
		local -n msg_ref=${14}
		local -n showcmd_ref=${15}
        local -n not_ref=${16}
        local -n func_ref=${17}
        local -n cmd_args_ref=${18}
        local -n ok_ref=${19}
		
		shift 19
		
		while [[ $# -gt 0 ]]; do
            # no command has been found yet
            if [[ -z "$func_ref" ]] ; then 
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
                    --begin)
                        begin_ref=true
                        shift
                        ;;
                    --end)
                        end_ref=true
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
                    --silent)
                        silent_ref=true
                        shift
                        ;;
                    --tree)
                        tree_ref=true
                        shift
                        ;;
                    --flat)
                        flat_ref=true
                        shift
                        ;;
                    --prompt)
                        prompt_ref=true
                        shift
                        ;;
                    --cmd|--show_command)
                        showcmd_ref=true
                        shift
                        ;;
                    --help)
                        show_help_ref=true
                        shift
                        ;;
                    --header)
                        if [[ -n "$2" && "$2" =~ ^[0-2]$ ]]; then
                            header_type_ref="$2"
                            shift 2
                        else
                            error -m "Header type as to be 0 1 or 2."
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
                    --not)
                        shift
                        while (( "$#" )); do
                            if [[ -n "$1" && "$1" != -* ]]; then
                                not_ref+=("$1")
                                shift
                            else
                                break
                            fi
                        done
                        ;;
                    --ok)
                        shift
                        while (( "$#" )); do
                            # ends with --ko
                            if [[ -n "$1" && "$1" != -* ]]; then
                                ok_ref+=("$1")
                                shift
                            else
                                break
                            fi
                        done
                        ;;
                    -f|--func)
                        func_ref="$2"
                        shift 2
                        ;;
                    -*|--*)
                        error -m "climb received invalid flag/command : $1"
                        ;;
                esac
            else
                # All remaining arguments after -f func are treated as func's arguments
                cmd_args_ref+=("$@") 
                break
            fi
		done
	}
	
	gitbranch() {
		local header=$(git -C "$dir/$path" rev-parse --abbrev-ref HEAD 2>&1)
		if [ "$?" != 0 ] ; then
			error -m "$header" 
		fi
		printf "(%s)" "$header"
	}
	
	gitbranch_modbranch() {
		local gitbranch=$(git -C "$dir/$path" rev-parse --abbrev-ref HEAD 2>&1)
		if [ "$?" != 0 ] ; then
			error -m "$gitbranch" 
		fi
		if $ISTRUNK ; then
			printf "(%s)" "$gitbranch" 
		else 
			local modbranch=$(get_module_key "$dir/.gitmodules" "$module" "branch" 2>&1)
			if [ "$?" != 0 ] ; then
				error -m "$modbranch" 
			fi
			printf "(%s) [%s]" "$gitbranch" "$modbranch"
		fi
		
	}
	
	get_module_header() {
		local header_ref=""
		case "$1" in
			0)
				header_ref=$(printf "")
				shift
				;;
			1)
				header_ref=$(gitbranch)
				shift
				;;
			2)
				header_ref=$(gitbranch_modbranch)
				shift
				;;
			*)
				error -m "Climb --tree unknow header option : $1"
				;;
		esac
		printf "$header_ref"
	}
		
	climbing() {
		local func="$1"
		local dir="$2"
		local path="$3"
		local module="$4"
        shift 4 
        local funcargs=("$@")
        
		local branching_up=false	
		
		# SILENT, FLAT , MODULE_HEADER and TREE are global to this function
		(( DEPTH += 1 ))
		
		local -i PAD=$((DEPTH * 4))
		if $FLAT ; then
			PAD=0
		fi
		
		if (( DEPTH > MAXDEPTH )); then
			error -m "Max depth reached in $dir"
		fi
		
		current_branch=$(git -C "$dir/$path" rev-parse --abbrev-ref HEAD)
		# On the way up
		if (( DEPTH > 0 )) && $UPWARD && [[ $INITIALIZATION == true || -f "$dir/$path/.gitmodules" ]] && $TREE ; then
			monkey_say "$SEP ${module} $(get_module_header $MODULE_HEADER)" -n --pad "$PAD" --color "$YELLOW" --silent "$SILENT"
		fi
		
		if (( DEPTH > 0 )) && $UPWARD && [[ $INITIALIZATION == true || -f "$dir/$path/.gitmodules" ]] && $BRANCHES ; then
			ISBRANCH=true
            if [[ " ${NOT[@]} " =~ " $module " ]]; then
                monkey_say "Skip $module" -n --pad "$PAD" --color "$YELLOW" -n --silent "$SILENT" 
            else
                monkey_catch -n --pad "$PAD" --color "$YELLOW" -n --silent "$SILENT" --prompt "$PROMPT" --show_command "$SHOW_COMMAND" --ok "${OK[@]}" --func "$func" "$dir" "$path" "$module" "${funcargs[@]}" 
            fi
			ISBRANCH=false
		fi
		
		if [ -f "$dir/$path/.gitmodules" ] ; then
			local names=()
			mapfile -t names < <(get_module_names "$dir/$path/.gitmodules")
			local len=${#names[@]}
			local i
			for ((i=0; i<$len; i++)); do
				local name="${names[$i]}"
				local subpath="$(get_module_key "$dir/$path/.gitmodules" "$name" "path")"
				climbing "$func" "$dir/$path" "$subpath" "$name" "${funcargs[@]}"
			done
		elif $LEAVES && (( DEPTH < MAXDEPTH )) && [ $INITIALIZATION == false ]; then
			if $TREE ; then
				monkey_say "$SEP ${module} $(get_module_header $MODULE_HEADER)" -n --pad "$PAD" --color "$GREEN" --silent "$SILENT"
			fi
			ISLEAVES=true
            if [[ " ${NOT[@]} " =~ " $module " ]]; then
                monkey_say "Skip $module" -n --pad "$PAD" --color "$GREEN" -n --silent "$SILENT" 
            else
                monkey_catch -n --pad "$PAD" --color "$GREEN" --silent "$SILENT" --prompt "$PROMPT" --show_command "$SHOW_COMMAND" --ok "${OK[@]}" --func "$func" "$dir" "$path" "$module" "${funcargs[@]}" 
            fi 
			ISLEAVES=false
		fi
		
		# On the way down
		if (( DEPTH > 0 ))	&& ! $UPWARD && [ -f "$dir/$path/.gitmodules" ] && $TREE ; then
			monkey_say "$SEP ${module} $(get_module_header $MODULE_HEADER)" -n --pad "$PAD" --color "$YELLOW" --silent "$SILENT"
		fi
		
		if (( DEPTH > 0 ))	&& ! $UPWARD && [ -f "$dir/$path/.gitmodules" ] && $BRANCHES ; then
			ISBRANCH=true
            if [[ " ${NOT[@]} " =~ " $module " ]]; then
                monkey_say "Skip $module" -n --pad "$PAD" --color "$YELLOW" -n --silent "$SILENT" 
            else
                monkey_catch -n --pad "$PAD" --color "$YELLOW" --silent "$SILENT" --prompt "$PROMPT" --show_command "$SHOW_COMMAND" --ok "${OK[@]}" --func "$func" "$dir" "$path" "$module" "${funcargs[@]}"
            fi 
			ISBRANCH=false
		fi
		
		(( DEPTH -= 1 ))
	}
	
	climb_parse SHOW_HELP LEAVES BRANCHES TRUNK UPWARD INITIALIZATION BEGIN END SILENT TREE FLAT MODULE_HEADER PROMPT MESSAGE SHOW_COMMAND NOT func FUNCARGS OK "${@}" 
	
    
	if $SHOW_HELP ; then
		climb_help
		exit 1
	fi
    
    if [[ -z $func ]] ; then
        error -m "climb had not function given to it."
    fi
	
	if $UPWARD ; then
		SEP="└──"
	else 
		SEP="┌──"
	fi
	
	if [[ -n $MESSAGE ]] ; then
		monkey_say "$MESSAGE" -n --color "$CYAN" --silent "$SILENT"
	fi
	
	if $BEGIN ; then
		ISBEGIN=true
		monkey_catch -n --color "$CYAN" --silent "$SILENT" --prompt "$PROMPT" --show_command "$SHOW_COMMAND" --ok "${OK[@]}" --func "$func" "$dir" "$dir" "Begin" "${FUNCARGS[@]}"
		ISBEGIN=false		
	fi
			
	if $TRUNK && $UPWARD; then
		ISTRUNK=true
		if $TREE ; then
		repo_path=$(git -C "$dir" rev-parse --show-toplevel)
		repo_name=$(basename "$repo_path")	
		monkey_say "${repo_name} $(get_module_header $MODULE_HEADER)" -n --color "$RED" --silent "$SILENT"
		fi
		monkey_catch -n --color "$RED" --silent "$SILENT" --prompt "$PROMPT" --show_command "$SHOW_COMMAND" --ok "${OK[@]}" --func "$func" "$dir" "$dir" "Trunk" "${FUNCARGS[@]}"
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
			climbing "$func" "$dir" "$path" "$name" "${FUNCARGS[@]}"
		done
	fi
	
	if $TRUNK && ! $UPWARD; then
		ISTRUNK=true
		if $TREE ; then
		repo_path=$(git -C "$dir" rev-parse --show-toplevel)
		repo_name=$(basename "$repo_path")	
		monkey_say "${repo_name} $(get_module_header $MODULE_HEADER)" -n --color "$RED" --silent "$SILENT"
		fi
		monkey_catch -n --color "$RED" --silent "$SILENT" --prompt "$PROMPT" --show_command "$SHOW_COMMAND" --ok "${OK[@]}" --func "$func" "$dir" "$dir" "Trunk" "${FUNCARGS[@]}"
		ISTRUNK=false
	fi	
		
	if $END ; then
		ISBEGIN=true
		monkey_catch -n --color "$CYAN" --silent "$SILENT" --prompt "$PROMPT" --show_command "$SHOW_COMMAND" --ok "${OK[@]}" --func "$func" "$dir" "$dir" "End" "${FUNCARGS[@]}"
		ISBEGIN=false		
	fi
		
	unset -f climbing -f climb_parse -f get_module_header -f gitbranch -f gitbranch_modbranch
}

dummy(){
    echo "Hi !"
}

plant() {
    # Plant is broken and need to be updated to work with new climb.
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
		monkey_say "git -C $dir submodule update --init $path" -n --pad "$((PAD+4))" --color "$CYAN" 
		monkey_catch -n --pad "$((PAD+4))" --color "$WHITE" --func git -C "$dir" submodule update --init "$path"		
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

		# This prompts the user for an answer but which is incompatible with monkey_catch
		# It should now hopefully be fixed (not tested yet)
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
	
	if [[ -z "BRANCH" ]] ; then
		error -m "Need a branch."
	fi
	
	repo_path=$(git -C "$dir" rev-parse --show-toplevel)
	repo_name=$(basename "$repo_path")
	
	local worktree_path="$dir/$NEWTREEPATH/${repo_name}_$BRANCH"
	answer="$(yes_no -m "Fetch origin first ?"  -d Y )"
	if $answer ; then
		monkey_catch -n --color "$CYAN" --func git fetch origin
	fi	
		
	answer="$(yes_no -m "Create new $BRANCH worktree ?"  -d Y )"
	if $answer ; then
		monkey_say "Planting branch '$BRANCH' at location '$worktree_path' " -n --color "$CYAN"
		monkey_catch -n --color "$CYAN" --except 128 --func git worktree add "$worktree_path" "$BRANCH"
		if [ $? -eq 128 ]; then 
			answer="$(yes_no -m "git worktree prune and try again ?"  -d Y )"
			if $answer ; then
			monkey_catch -n --color "$CYAN" --func git worktree prune
			monkey_catch -n --color "$CYAN" --func git worktree add "$worktree_path" "$BRANCH"
			fi				  
		fi
	fi
	
	cd "$worktree_path" 
	dir="." 
	
	answer="$(yes_no -m "Initialize and setup submodules ?"  -d Y )"
	if $answer ; then
		climb --init --trunk --branches --leaves --up --func plant_tree 
	fi
	
	answer="$(yes_no -m "Are there submodules's to protect from being pushed/mutes ? "  -d Y )"
	if $answer ; then
		mute
	fi
	
	monkey_say "INITIALIZATION DONE ! " -n --color "$CYAN" 
	tree
	
	answer="$(yes_no -m "Commit changes ? "  -d N )"
	if $answer ; then
		DOS2UNIX
		grow -m "$BRANCH worktree initialization."
	fi
	
	answer="$(yes_no -m "Push ? "  -d N )"
	if $answer ; then
		push
	fi
	
	unset -f plant_tree -f plant_parse -f set_branch -f init_module
}

tree() {
local str="Legend :
\t(HEAD) as returned by git rev-parse --abbrev-ref HEAD
\t[branch] as declared in .gitmodules
"
	command(){
	if $ISBEGIN ; then
		#echo ""
		monkey_say "$str" -n --pad 0 --color "$CYAN"
		#echo ""
	fi
	}
	climb  --tree --header 2 --begin --trunk --branches --leaves --up --func command
	
	unset -f command
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
	checkout
	tree
	
	unset -f parse
}

checkout() {
	local SHOW_HELP=false
    local CLIMBARGS=()
	
	checkout_parse() {
		local -n show_help_ref=$1
        local -n climb_args_ref=$2
		shift 2
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
                    climb_args_ref+=("$1") 
                    shift
                ;;
			esac
		done
	}
	
	checkout_parse SHOW_HELP CLIMBARGS "${@}"
	if $SHOW_HELP; then
		checkout_help
		exit 1
	fi
	
	checkout_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		local branch=$(get_module_key "$dir/.gitmodules" "$name" "branch")
		if [[ -n "$branch" ]]; then
			# monkey_say "$path checkout $branch" -n --color "$GREEN"
			git -C "$dir/$path" checkout "$branch" 
		fi
	}
	
	climb --tree --header 2 --branches --leaves --up "${CLIMBARGS[@]}" --func checkout_module 
	
	unset -f checkout_module -f checkout_parse
}

pull() {
	local SHOW_HELP=false
	local FORCE_REBASE=false
	local FORCE_MERGE=false
    local CLIMBARGS=()
	
	pull_parse() {
		local -n show_help_ref=$1
		local -n force_rebase_ref=$2
		local -n force_merge_ref=$3
        local -n climb_args_ref=$4
		shift 4
		
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
                    climb_args_ref+=("$1") 
                    shift
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
		
		monkey_say "$path pull " -n --color "$GREEN" 
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
	
	pull_parse SHOW_HELP FORCE_REBASE FORCE_MERGE CLIMBARGS "${@}"
	if $SHOW_HELP; then
		pull_help
		exit 1
	fi
	
	climb --tree --header 1 --trunk --branches --leaves --up "${CLIMBARGS[@]}" --func pull_module
	
	unset -f pull_module -f pull_parse
}

push() {
	local SHOW_HELP=false
	local FORCE=false
    local CLIMBARGS=()
	
	push_parse() {
		local -n show_help_ref=$1
		local -n force_ref=$2
		local -n climb_args_ref=$3
        shift 3
		
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
                    climb_args_ref+=("$1") 
                    shift
                ;;
			esac
		done
	}
	push_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		
		# will return "no_push" when repo as been set to mute
		pushurl="$(git -C "$dir/$path" remote get-url origin --push)"
		
		if [[ -z "$pushurl" ]] || [ "$pushurl" == "no_push" ] ; then
			echo "skip"
			return 0 
		fi
		
		if [ "$FORCE" != true ] ; then
            git -C "$dir/$path" push
		elif [ "$FORCE" == true ] ; then
            git -C "$dir/$path" push --force
		fi	
	}
	
	push_parse SHOW_HELP FORCE CLIMBARGS "${@}"
	if $SHOW_HELP; then
		push_help
		exit 1
	fi
	
	climb -m "Pushing to remote." --tree --header 1 --trunk --branches --leaves --up "${CLIMBARGS[@]}" --func push_module 
	
	unset -f push_module -f push_parse
}

add() {
# This function doesn't automatically add modules
# Use grow for that
	local SHOW_HELP=false
	local ALL=false
	local FILE=""
    local CLIMBARGS=()

	add_parse() {
	local -n show_help_ref=$1
	local -n all_ref=$2
	local -n file_ref=$3
	local -n climb_args_ref=$4
    shift 4

	while [[ $# -gt 0 ]]; do
	  case "$1" in
		--help)
		  show_help_ref=true
		  shift
		;;
		-a|--all)
			all_ref=true
			shift
		;;
		-f|--file)
			if [[ -n "$2" && "$2" != -* ]]; then
				if [[ "$2" == "." ]] ; then 
					all_ref=true
				else 
					file_ref="$2"
				fi
				shift 2
			else
				error -m "-f|--file requires a file argument"
			fi
		;;
		*)
			climb_args_ref+=("$1") 
            shift
		;;
	  esac
	done
	}
	add_module() {
		local dir="$1"
		local path="$2"
		local name="$3"
        
		if [[ -n "$FILE" ]]; then
			git -C "$dir/$path" add "$FILE"
		elif $ALL ; then
			git -C "$dir/$path" add --all 
			if ! $ISTRUNK ; then
				git -C "$dir" reset "$path"
			fi
		fi
		
	}
    
	add_parse SHOW_HELP ALL FILE CLIMBARGS "${@}"

	if $SHOW_HELP || [[ $ALL == false &&  -z "$FILE" ]]; then
	add_help
	exit 1
	fi

	climb --tree --header 1 --trunk --branches --leaves --up "${CLIMBARGS[@]}" --ok 128 --func add_module 

	unset -f add_module -f add_parse 
}


# I'm avoiding collision with bash's reset function for now
reset_modules() {
	local SHOW_HELP=false
    local CLIMBARGS=()
	
	reset_parse() {
		local -n show_help_ref=$1
		local -n climb_args_ref=$2
        shift 2
		
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
                    climb_args_ref+=("$1") 
                    shift
                ;;
			esac
		done
	}
	reset_module(){
		local dir="$1"
		local path="$2"
		local name="$3"
		monkey_say "$path reset " -n --color "#GREEN"
		git -C "$dir/$path" reset
	}
	
	reset_parse SHOW_HELP CLIMBARGS "${@}"
	if $SHOW_HELP; then
		reset_help
		exit 1
	fi
	
	climb --tree --header 1 --trunk --branches --leaves --up "${CLIMBARGS[@]}" --func reset_module 
	
	unset -f reset_module -f reset_parse
}

commit() {
	local SHOW_HELP=false
	local MESSAGE=""
    local CLIMBARGS=()

	commit_parse() {
		local -n show_help_ref=$1
		local -n message_ref=$2
		local -n climb_args_ref=$3
        shift 3
		
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
				*)
                    climb_args_ref+=("$1") 
                    shift
                ;;
			esac
		done
	}

	commit_module(){
		local dir="$1"
		local path="$2"
		#local name="$3" 
        local MESSAGE="$4"
		if [[ -z $(git -C "$dir/$path" status --porcelain) ]]; then
			echo "Nothing to commit, working tree clean."
		else
			git -C "$dir/$path" commit -m "$MESSAGE"
		fi
	}

	commit_parse SHOW_HELP MESSAGE CLIMBARGS "${@}"
	if $SHOW_HELP; then
		commit_help
		exit 1
	fi

	if [[ -z "$MESSAGE" ]]; then
		error -m "Commit message is required. Use -m <message> to provide a commit message."
	fi

	climb -m "Commiting file change only" --tree --header 1 --trunk --branches --leaves --up "${CLIMBARGS[@]}" --func commit_module "$MESSAGE"

	unset -f commit_module -f commit_parse
}

grow() {
	# This is only for commiting module
	# it you want to commit individual file see add and commit
	local SHOW_HELP=false
	local MESSAGE=""
    local CLIMBARGS=()
	
	grow_parse() {
		local -n show_help_ref=$1
		local -n message_ref=$2
		local -n climb_args_ref=$3
		shift 3
				
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
				*)
                    climb_args_ref+=("$1") 
                    shift
                ;;
			esac
		done
	}
	
	_commit(){
		local path="$1"
		local message="$2"
		if [[ -z $(git -C "$path" status --porcelain) ]]; then
			echo "Nothing to commit, working tree clean."
		else
			git -C "$path" commit -m "$message"
		fi

	}
	
	grow_module(){
		local dir="$1"
		local path="$2"
		#local name="$3"
        local MESSAGE="$4"
		if $ISLEAVES ; then
			git -C "$dir" add "$path"
		elif $ISTRUNK ; then
			_commit "$dir" "$MESSAGE"
		else 
			_commit "$dir/$path" "$MESSAGE"
			git -C "$dir" add "$path"
		fi
	
	}
	
	grow_parse SHOW_HELP MESSAGE CLIMBARGS "${@}"
	if $SHOW_HELP; then
		grow_help
		exit 1
	fi
	
	if [[ -z "$MESSAGE" ]]; then
		error -m "Commit message is required. Use -m <message> to provide a commit message."
	fi
	
	climb -m "Add and Commit modules" --tree --header 1 --trunk --branches --leaves --down "${CLIMBARGS[@]}" --func grow_module "$MESSAGE"
	
	unset -f grow_module -f grow_parse -f _commit
}

mute() {
	local SHOW_HELP=false
	local UNDO=false
	local COMMAN=""
	local MESSAGE=""
	local SHOW=false
    local CLIMBARGS=()
	
	mute_parse() {
		local -n show_help_ref=$1
		local -n undo_ref=$2
		local -n show_ref=$3
        local -n climb_args_ref=$4
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
				*)
                    climb_args_ref+=("$1")
                    shift                    
                ;;
			esac
		done
	}
	
	mute_cmd() {
        local dir="$1"
		local path="$2"
		#local name="$3"
		git -C "$dir/$path" remote set-url --push origin no_push
	}
	
	undo_cmd() {
        local dir="$1"
		local path="$2"
		#local name="$3"
		pullurl="$(git -C "$dir/$path" remote get-url origin)"
		git -C "$dir/$path" remote set-url --push origin "$pullurl"
	}
	
	show_cmd() {
        local dir="$1"
		local path="$2"
		#local name="$3"
		pushurl="$(git -C "$dir/$path" remote get-url origin --push)"
		echo "$pushurl"
	}
	
	mute_parse SHOW_HELP UNDO SHOW CLIMBARGS "${@}"
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
		climb --prompt --tree --header 1 --trunk --branches --leaves -m "$MESSAGE" "${CLIMBARGS[@]}" --func $COMMAND 
	else
		climb --tree --header 1 --trunk --branches --leaves -m "$MESSAGE" "${CLIMBARGS[@]}" --func $COMMAND 
	fi
	
	unset -f mute_parse  -f mute_cmd -f undo_cmd -f show_cmd
}

status() {
	local SHOW_HELP=false
    local CLIMBARGS=()
	
	parse() {
		local -n show_help_ref=$1
        local -n climb_args_ref=$2
		shift 2

		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
				*)
                    climb_args_ref+=("$1")
                    shift
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
		if [[ -z "$status" ]] ; then
			status="Up to date"
		fi
		printf "$status"
	}
	
	parse SHOW_HELP CLIMBARGS "${@}"
    
	if $SHOW_HELP; then
		status_help
		exit 1
	fi
	
	climb --tree --header 1 --trunk --branches --leaves "${CLIMBARGS[@]}" --func command 
	
	unset -f parse -f command
}

stash() {
	local SHOW_HELP=false
	local POP=false
    local CLIMBARGS=()
	
	parse() {
		local -n show_help_ref=$1
		local -n pop_ref=$1
        local -n climb_args_ref=$2
		shift 3

		while [[ $# -gt 0 ]]; do
			case "$1" in
				--help)
					show_help_ref=true
					shift
					;;
                pop)
					pop_ref=true
					shift
					;;
				*)
                    climb_args_ref+=("$1")
                    shift
                ;;
			esac
		done
	}
	
	command() {
        if $POP ; then
            git -C "$1/$2" stash pop
        else
            git -C "$1/$2" stash pop
        fi
	}
	
	parse SHOW_HELP POP CLIMBARGS "${@}"
    
	if $SHOW_HELP; then
		stash_help
		exit 1
	fi
	
	climb --tree --header 1 --trunk --branches --leaves --down "${CLIMBARGS[@]}" --func command 
	
	unset -f parse -f command
}


branch() {
    #deprecated
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
	
	climb --tree --header 1 --trunk --branches --leaves --func command 
	
	unset -f parse -f command
}

DOS2UNIX() {
	command() {
		dos2unix "$1/.gitmodules"
	}
	
	climb --tree --header 1 --trunk --branches --leaves --func command 
	
	unset -f command
}

IGNORE() {
  local SHOW_HELP=false
  local REMOVE=false
  local LINE=""
  local CLIMBARGS=()
  local MESSAGE=""

  parse() {
    local -n show_help_ref=$1
    local -n remove_ref=$2
    local -n line_ref=$3
    local -n climb_args_ref=$4
    shift 4

    while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help_ref=true
			shift
			;;
		-l|--line)
			if [[ -n "$2" && "$2" != -* ]]; then
				line_ref="$2"
				shift 2
			else
				error -m "-l|--line Requires a string"
			fi
		;;
		--remove)
			remove_ref=true
			shift
		;; 
		*)
			climb_args_ref+=("$1") 
            shift
		;;
		esac
    done
  }

  parse SHOW_HELP REMOVE LINE CLIMBARGS "${@}"
  
  if $SHOW_HELP; then
    IGNORE_help
    exit 1
  fi
  
  if [[ -z "$LINE" ]] ; then
    error -m "Requires a line to be added or removed from .gitignore"
  fi

  # Function to add a line if it doesn't already exist
  add_line_if_not_exists() {
    local line_to_add="$1"
    local file="$2"

    # Escape special characters for the shell (especially `!`), using printf to safely handle the backslash and other escapes
    line_to_add=$(printf '%s' "$line_to_add" | sed 's/[!]/\\&/g')

    # Check if the line (trimmed of surrounding spaces) exists in the file
    if ! awk -v line="$line_to_add" 'BEGIN { trimmed_line = gensub(/^[ \t]+|[ \t]+$/, "", "g", line) }
        { if (gensub(/^[ \t]+|[ \t]+$/, "", "g") == trimmed_line) found = 1 }
        END { exit found ? 0 : 1 }' "$file"; then
      echo "$line_to_add" >> "$file"
    fi
  }

  # Function to remove a line if it exists
  remove_line_if_exists() {
    local line_to_remove="$1"
    local file="$2"

    # Escape special characters for the shell (especially `!`), using printf to safely handle the backslash and other escapes
    line_to_remove=$(printf '%s' "$line_to_remove" | sed 's/[!]/\\&/g')

    # Remove the line (trimmed of surrounding spaces) from the file
    awk -v line="$line_to_remove" 'BEGIN { trimmed_line = gensub(/^[ \t]+|[ \t]+$/, "", "g", line) }
        { if (gensub(/^[ \t]+|[ \t]+$/, "", "g") != trimmed_line) print }' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  }

   if $REMOVE ; then
		MESSAGE="Removing $LINE from .gitignore"
	else
		MESSAGE="Adding $LINE to .gitignore"
	fi

  # Function to apply the add or remove operation
  command() {
    local dir="$1"
    local path="$2"
    local name="$3"
	
	local file=""
	if $ISTRUNK ; then	
		file="$dir/.gitignore"
    else
		file="$dir/$path/.gitignore"
    fi
	
	local _command_=""
	if $REMOVE ; then
		_command_=remove_line_if_exists
	else
		_command_=add_line_if_not_exists
	fi
	
	if [ -f "$file" ] ; then
		"$_command_" "$LINE" "$file"
	fi
  }

  # Call the command function to apply to all submodules
  climb -m "$MESSAGE" --tree --header 1 --trunk --branches --leaves "${CLIMBARGS[@]}" --func command 

  # Clean up function definitions
  unset -f add_line_if_not_exists -f remove_line_if_exists -f parse -f command
}

RESTORE() {
	local FILE=""
    local CLIMBARGS=()

	parse() {
	local -n file_ref=$1
	local -n climb_args_ref=$2
	shift 2

	while [[ $# -gt 0 ]]; do
	  case "$1" in
		-f|--file)
			if [[ -n "$2" && "$2" != -* ]]; then
				file_ref="$2"
				shift 2
			else
				error -m "-f|--file requires a file argument"
			fi
		;;
		*)
            climb_args_ref+=("$1") 
            shift
        ;;
	  esac
	done
	}
	command() {
		local dir="$1"
		local path="$2"
		local name="$3"

		monkey_say "Restoring $FILE " -n --color "$GREEN" # green
		
		git -C "$dir/$path" restore "$FILE"
	}

	parse FILE CLIMBARGS "${@}"
	
	climb --trunk --branches --leaves --up "${CLIMBARGS[@]}" --func command 

	unset -f command -f parse 
}

git-monkey "${@}"

)

