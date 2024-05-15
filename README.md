# GitMaster
(WIP) A helper to manage git projects with multiple submodules and their submodules

## Overview

The Git Submodule Manager is a bash script designed to simplify the management of Git projects with multiple submodules, which may also have their own submodules. 
This script provides a range of functionalities, including checking out branches, pulling and pushing changes, committing with messages, and squashing commits across all submodules.

## Features

- **Checkout Branch**: Check out all submodules to a specified branch.
- **Pull Changes**: Pull changes from the remote repositories of all submodules.
- **Push Changes**: Push changes to the remote repositories of all submodules.
- **Force Push Changes**: Forcefully push changes to the remote repositories of all submodules.
- **Commit Changes**: Commit changes in all submodules and the parent repository with a given message.
- **Squash Commits**: Squash commits in all submodules and the parent repository with a given message and an optional time window.

## Usage

\`\`\`bash
./git-master.sh [OPTIONS]
\`\`\`

### Options

- `-h`, `--help`: Display the help message.
- `-ch`, `--checkout BRANCH`: Check out all submodules to the specified branch.
- `-pl`, `--pull`: Pull changes from the remote repositories of all submodules.
- `-ps`, `--push`: Push changes to the remote repositories of all submodules.
- `-fp`, `--force-push`: Forcefully push changes to the remote repositories of all submodules.
- `-c`, `--commit MESSAGE`: Commit changes in all submodules and the parent repository with the given message.
- `-s`, `--squash MESSAGE [TIME_WINDOW]`: Squash commits in all submodules and the parent repository with the given message and an optional time window (e.g., '1 day ago' or '12 hours ago').

## Functions

### Helper Functions

- **usage()**: Displays the usage instructions.
- **generate_submodule_tree()**: Recursively generates the submodule tree.
- **get_all_submodules()**: Retrieves all submodule paths recursively.
- **sort_deepest_first()**: Sorts paths with the deepest directories first.
- **sort_shallowest_first()**: Sorts paths with the shallowest directories first.
- **remove_duplicate_paths()**: Removes duplicate paths, retaining the shortest one.
- **find_unique_paths()**: Finds unique paths not present in a list of non-duplicate paths.
- **special_print()**: Prints a message with special formatting.
- **status_paths()**: Displays the short status of all submodules.

### Main Functions

- **checkout_branch(branch)**: Checks out the specified branch if it exists.
- **checkout_paths(branch, paths)**: Checks out the specified branch in all provided paths.
- **pull_paths(paths)**: Pulls changes from the remote repositories for all provided paths.
- **push_paths(paths)**: Pushes changes to the remote repositories for all provided paths.
- **force_push_paths(paths)**: Forcefully pushes changes to the remote repositories for all provided paths.
- **squash_commits(message, paths, time_window)**: Squashes commits with the given message and time window for all provided paths.
- **commit_paths(message, paths)**: Commits changes with the given message for all provided paths.

## Example Usage

### Checkout Branch

\`\`\`bash
./git-master.sh --checkout develop
\`\`\`

This command checks out the `develop` branch in all submodules.

### Pull Changes

\`\`\`bash
./git-master.sh --pull
\`\`\`

This command pulls changes from the remote repositories of all submodules.

### Commit Changes

\`\`\`bash
./git-master.sh --commit "Updated submodule configurations"
\`\`\`

This command commits changes with the message "Updated submodule configurations" in all submodules and the parent repository.

### Squash Commits

\`\`\`bash
./git-master.sh --squash "Squashed commits" "1 week ago"
\`\`\`

This command squashes commits with the message "Squashed commits" from the last week in all submodules and the parent repository.

## Contributing

Feel free to fork this repository, make improvements, and submit pull requests. Contributions are welcome!

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

---

This markdown file provides an overview of the Git Submodule Manager script, detailing its features, usage, functions, and example commands to help users manage their projects with multiple git submodules effectively.
