#!/bin/bash
# Made By Star_destroyer11

# Module Manager
# Shell scripting was a mistake, but im too far in now.

source /usr/lib/libmosh.sh

MODULE_DIR="/usr/local/share/modmium/modules"

# MMM needs a pause. The terminal does not.
pause() {
    read -rp "Press Enter to continue..."
}

# Find every module directory with a shell entrypoint.
get_modules() {
    [ -d "$MODULE_DIR" ] || return 0

    find "$MODULE_DIR" -type f -name "*.sh" -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            dir="${file%/*}"

            # Only use the first shell script in each module folder.
            first=$(find "$dir" -maxdepth 1 -type f -name "*.sh" -print 2>/dev/null | sort | head -n1)

            [ "$file" = "$first" ] && printf '%s\n' "$file"
        done |
        sort -u
}

# Load a module.
load_module() {
    local file="$1"

    [ -f "$file" ] || return 1

    unset MODULE_ID
    unset MODULE_NAME
    unset MODULE_VERSION
    unset MODULE_AUTHOR
    unset MODULE_DESCRIPTION
    unset MODULE_REPOSITORY
    unset MODULE_LICENSE
    unset MODULE_MIN_VERSION
    unset MODULE_MAX_VERSION
    unset MODULE_REQUIRES_ROOT
    unset MODULE_REQUIRES_INTERNET
    unset MODULE_CONFLICTS
    unset MODULE_CONFIG
    unset MODULE_HAS_TUI

    # Yes, i sourcing shell code. What could go wrong?
    source "$file"
}

module_files=()
module_names=()

# Refresh the module list.
refresh_modules() {
    module_files=()
    module_names=()

    while IFS= read -r file; do
        [ -n "$file" ] || continue

        module_files+=("$file")

        load_module "$file"
        module_names+=("${MODULE_NAME:-$(basename "$(dirname "$file")")}")
    done < <(get_modules)
}

# Launch a module.
launch_module() {
    local file="$1"

    [ -f "$file" ] || return

    load_module "$file"

    clear

    if [ "${MODULE_HAS_TUI:-false}" = true ]; then
        if declare -F module_menu >/dev/null 2>&1; then
            module_menu
        elif declare -F tui >/dev/null 2>&1; then
            tui
        else
            echo "Module does not provide a TUI."
            pause
        fi
    else
        echo "Module does not provide a TUI."
        pause
    fi
}

# Open installed modules.
modules() {
    refresh_modules

    if [ "${#module_files[@]}" -eq 0 ]; then
        clear
        echo "Modmium Modules"
        echo "========================"
        echo
        echo "No modules installed."
        echo
        pause
        return
    fi

    options=()
    functions=()

    for i in "${!module_names[@]}"; do
        options+=("${module_names[$i]}")
        functions+=("module_launch_$i")
    done

    options+=("Back")
    functions+=("module_list_back")

    # Give each module its own little button.
    for i in "${!module_files[@]}"; do
        eval "module_launch_$i() {
            launch_module \"\${module_files[$i]}\"
        }"
    done

    module_list_back() {
        return
    }

    num_options="${#options[@]}"
    selected_index=0

    full_menu
}

# Install a module from a file.
install_module_file() {
    clear

    echo "Install Module"
    echo "========================"
    echo
    echo "Enter the path to the module's .sh file."
    echo

    read -rp "Module file: " file

    if [ ! -f "$file" ]; then
        echo
        echo "File not found."
        pause
        return
    fi

    local module_id

    module_id=$(grep '^MODULE_ID=' "$file" |
        head -n1 |
        sed 's/^MODULE_ID=//' |
        tr -d '"')

    if [ -z "$module_id" ]; then
        echo
        echo "Invalid module."
        echo "MODULE_ID is missing."
        pause
        return
    fi

    mkdir -p "$MODULE_DIR/$module_id"

    cp "$file" "$MODULE_DIR/$module_id/$(basename "$file")"

    echo
    echo "Module installed."
    pause
}

# Install a module from a URL.
install_module_url() {
    clear

    echo "Install Module"
    echo "========================"
    echo

    read -rp "Module URL: " url

    local tmp="/tmp/modmium-module.sh"

    # Download it and hope the server behaves.
    if ! curl -fsSL "$url" -o "$tmp"; then
        echo
        echo "Failed to download module."
        rm -f "$tmp"
        pause
        return
    fi

    local module_id
    local filename

    module_id=$(grep '^MODULE_ID=' "$tmp" |
        head -n1 |
        sed 's/^MODULE_ID=//' |
        tr -d '"')

    if [ -z "$module_id" ]; then
        echo
        echo "Invalid module."
        rm -f "$tmp"
        pause
        return
    fi

    filename=$(basename "${url%%\?*}")

    case "$filename" in
        *.sh)
            ;;
        *)
            filename="module.sh"
            ;;
    esac

    mkdir -p "$MODULE_DIR/$module_id"
    cp "$tmp" "$MODULE_DIR/$module_id/$filename"

    rm -f "$tmp"

    echo
    echo "Module installed."
    pause
}

# Repository support goes here.
install_module_repository() {
    clear

    echo "Install Module"
    echo "========================"
    echo
    echo "Modmium Repository support coming soon."
    echo

    pause
}

# Install menu.
install_module() {
    options=(
        "Modmium Repository"
        "File"
        "URL"
        "Back"
    )

    functions=(
        "install_module_repository"
        "install_module_file"
        "install_module_url"
        "install_module_back"
    )

    install_module_back() {
        return
    }

    num_options="${#options[@]}"
    selected_index=0

    full_menu
}

# Remove one module.
remove_module_by_file() {
    local file="$1"

    load_module "$file"

    clear

    echo "Remove Module"
    echo "========================"
    echo
    echo "Module: ${MODULE_NAME:-Unknown}"
    echo "ID:     ${MODULE_ID:-Unknown}"
    echo

    read -rp "Remove this module? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$MODULE_DIR/$MODULE_ID"

        # Gone. Reduced to atoms.
        echo
        echo "Module removed."
    else
        echo
        echo "Cancelled."
    fi

    pause
}

# Remove menu.
remove_module() {
    refresh_modules

    if [ "${#module_files[@]}" -eq 0 ]; then
        clear
        echo "Remove Module"
        echo "========================"
        echo
        echo "No modules installed."
        pause
        return
    fi

    options=()
    functions=()

    for i in "${!module_names[@]}"; do
        options+=("${module_names[$i]}")
        functions+=("remove_module_$i")
    done

    options+=("Back")
    functions+=("remove_module_back")

    for i in "${!module_files[@]}"; do
        eval "remove_module_$i() {
            remove_module_by_file \"\${module_files[$i]}\"
        }"
    done

    remove_module_back() {
        return
    }

    num_options="${#options[@]}"
    selected_index=0

    full_menu
}

# Toggle one module.
toggle_module_by_file() {
    local file="$1"

    load_module "$file"

    local module_path
    local enabled_file

    module_path="$(dirname "$file")"
    enabled_file="$module_path/enabled"

    if [ -f "$enabled_file" ]; then
        rm -f "$enabled_file"

        if declare -F disable >/dev/null 2>&1; then
            disable
        fi
    else
        touch "$enabled_file"

        if declare -F enable >/dev/null 2>&1; then
            enable
        fi
    fi
}

# Toggle modules with arrow keys.
toggle_modules() {
    refresh_modules

    if [ "${#module_files[@]}" -eq 0 ]; then
        clear
        echo "Installed Modules"
        echo "========================"
        echo
        echo "No modules installed."
        pause
        return
    fi

    local selected=0
    local count="${#module_files[@]}"

    while true; do
        clear

        echo "Installed Modules"
        echo "========================"
        echo

        for i in "${!module_files[@]}"; do
            load_module "${module_files[$i]}"

            local state="OFF"

            [ -f "$(dirname "${module_files[$i]}")/enabled" ] && state="ON"

            if [ "$i" -eq "$selected" ]; then
                printf "> %-30s [%s]\n" "${module_names[$i]}" "$state"
            else
                printf "  %-30s [%s]\n" "${module_names[$i]}" "$state"
            fi
        done

        echo
        echo "←/→ Toggle    ↑/↓ Select    Q Back"

        read -rsn1 key

        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 1 keyseq

            case "$keyseq" in
                '[A')
                    selected=$((selected - 1))

                    [ "$selected" -lt 0 ] &&
                        selected=$((count - 1))
                    ;;

                '[B')
                    selected=$((selected + 1))

                    [ "$selected" -ge "$count" ] &&
                        selected=0
                    ;;

                '[D'|'[C')
                    toggle_module_by_file "${module_files[$selected]}"
                    ;;
            esac

        elif [[ "$key" =~ [qQ] ]]; then
            return
        fi
    done
}

# Manage modules.
manage_modules() {
    options=(
        "Install Module"
        "Remove Module"
        "Enable/Disable Modules"
        "Back"
    )

    functions=(
        "install_module"
        "remove_module"
        "toggle_modules"
        "manage_modules_back"
    )

    manage_modules_back() {
        return
    }

    num_options="${#options[@]}"
    selected_index=0

    full_menu
}

# Check every installed module.
check_updates() {
    clear

    echo "Check for Updates"
    echo "========================"
    echo

    refresh_modules

    if [ "${#module_files[@]}" -eq 0 ]; then
        echo "No modules installed."
        pause
        return
    fi

    for file in "${module_files[@]}"; do
        load_module "$file"

        echo "${MODULE_NAME:-Unknown Module} v${MODULE_VERSION:-unknown}"

        if [ -n "${MODULE_REPOSITORY:-}" ]; then
            echo "Repository: $MODULE_REPOSITORY"
        fi

        echo
    done

    echo "Update checking coming soon."
    pause
}

# Show module information.
show_module_information() {
    local file="$1"

    load_module "$file"

    clear

    echo "Module Information"
    echo "========================"
    echo
    echo "ID:                 ${MODULE_ID:-Unknown}"
    echo "Name:               ${MODULE_NAME:-Unknown}"
    echo "Version:            ${MODULE_VERSION:-Unknown}"
    echo "Author:             ${MODULE_AUTHOR:-Unknown}"
    echo "Description:        ${MODULE_DESCRIPTION:-None}"
    echo "Repository:         ${MODULE_REPOSITORY:-None}"
    echo "License:            ${MODULE_LICENSE:-Unknown}"
    echo "Minimum Modmium:    ${MODULE_MIN_VERSION:-None}"
    echo "Maximum Modmium:    ${MODULE_MAX_VERSION:-None}"
    echo "Requires Root:      ${MODULE_REQUIRES_ROOT:-false}"
    echo "Requires Internet:  ${MODULE_REQUIRES_INTERNET:-false}"
    echo "Conflicts:          ${MODULE_CONFLICTS:-None}"
    echo "Config:             ${MODULE_CONFIG:-None}"
    echo "Has TUI:            ${MODULE_HAS_TUI:-false}"
    echo

    pause
}

# Module information menu.
module_information() {
    refresh_modules

    if [ "${#module_files[@]}" -eq 0 ]; then
        clear
        echo "Module Information"
        echo "========================"
        echo
        echo "No modules installed."
        pause
        return
    fi

    options=()
    functions=()

    for i in "${!module_names[@]}"; do
        options+=("${module_names[$i]}")
        functions+=("module_info_$i")
    done

    options+=("Back")
    functions+=("module_info_back")

    for i in "${!module_files[@]}"; do
        eval "module_info_$i() {
            show_module_information \"\${module_files[$i]}\"
        }"
    done

    module_info_back() {
        return
    }

    num_options="${#options[@]}"
    selected_index=0

    full_menu
}

# Main MMM menu.
mmm() {
    options=(
        "Modules"
        "Manage Modules"
        "Check for Updates"
        "Module Information"
        "Exit"
    )

    functions=(
        "modules"
        "manage_modules"
        "check_updates"
        "module_information"
        "mmm_exit"
    )

    mmm_exit() {
        return
    }

    num_options="${#options[@]}"
    selected_index=0

    full_menu
}

mmm
