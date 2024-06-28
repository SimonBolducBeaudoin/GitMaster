# GitMaster
(WIP) A helper to manage git projects with multiple submodules and their submodules

## Overview

The Git Submodule Manager is a bash script designed to simplify the management of Git projects with multiple submodules, which may also have their own submodules. 
It is 100% in bash which helps for portability.

## Usage

### General Usage

Run the script in bash (unix) or in Git bash (windows)
```bash
. /git-master.sh 
```
This exports the gitmod functon in your environnement.
gitmod is made to have an interface similar to git (when possible),
```sh
gitmod [-h | --help] [-C <path>] <command> [<args>]
```
but commands should be though of as beeing applied to the current repo and all its subrepo (modules) and all theirs ...
Commands :
- **tree**: Prints the tree of modules.
- **climb**: A helper to recursively iterate over modules. Similar to but wiser than 'git submodule foreach'.
- **grow**: Add and commit (leaves --> trunk ).
- **checkout**: Checkouts the branches defined in `.gitmodules` (trunk first).
- **pull**: Pulls and stops at conflicts (trunk first).
- **add**: Adds files to the index for each module (leaves first).
- **reset**: Git reset all modules.
- **commit**: Record changes to the repository for each module and stops at conflicts (leaves first).
		
### Commands

#### `tree`

Prints the tree of modules.

```sh
gitmod tree
```

#### `climb`

Helps to recursively iterate over modules.

```sh
gitmod climb <func> [options]
```

Options:

- `--leaves`: Execute on leaves.
- `--branches`: Execute on branches.
- `--trunk`: Execute on trunk.
- `--up`: Climb up the tree.
- `--down`: Climb down the tree.

#### `grow`

Add and commit from leaves to trunk.

```sh
gitmod grow
```

#### `checkout`

Checkouts the branches defined in `.gitmodules`.

```sh
gitmod checkout
```

#### `pull`

Pulls and stops at conflicts (trunk first).

```sh
gitmod pull [--rebase | --merge]
```

#### `add`

Adds files to the index for each module (leaves first).

```sh
gitmod add [--module | --all | --no-module]
```

#### `reset`

Git reset all modules.

```sh
gitmod reset
```

#### `commit`

Record changes to the repository for each module and stops at conflicts (leaves first).

```sh
gitmod commit -m <message> [options]
```

Options:

- `--trunk`
- `--branches`
- `--leaves`

## Examples

### Tree of Modules

```sh
gitmod tree
```

### Climb Example

```sh
dummy() {
    dir="$1"
    path="$2"
    name="$3"
    echo "Module $name in directory $dir"
    git -C "$path" log --all --decorate --oneline --graph -n1
}
gitmod climb dummy --trunk --leaves --down
```

### Checkout Branches

```sh
gitmod checkout -C /path/to/repo
```

### Pull with Rebase

```sh
gitmod pull --rebase
```

### Add and Commit Module Pointers

```sh
gitmod add -C /path/to/repo --modules
gitmod commit -m 'Updating modules'
```

## Tips
### Setup a module as pull only
If you don't indent to participate/push to a certain (sub)module it's a good idea to prevent your self from accidentally pushing to that repo.
An easy way to do that is to set the push url to a dummy value ('no_push')

```sh
cd path/to/your/submodule
git remote set-url --push origin no_push
```




## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

---
