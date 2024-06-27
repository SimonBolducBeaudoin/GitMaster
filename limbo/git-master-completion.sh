#!/bin/bash

_git_master_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-h --help -ch --checkout -pl --pull -ps --push -fp --force-push -c --commit -s --squash"

    case "${prev}" in
        git-*)
            COMPREPLY=( "git-master.sh" )
            return 0
            ;;
        -*)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        *)
            # Complete branch names for the --checkout option
            if [[ "${prev}" == "-ch" || "${prev}" == "--checkout" ]]; then
                local branches
                branches=$(git branch --list)
                COMPREPLY=( $(compgen -W "${branches}" -- ${cur}) )
                return 0
            fi
            ;;
    esac
}

complete -F _git_master_completion git-master.sh
