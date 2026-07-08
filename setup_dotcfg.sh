#!/bin/bash
# --- dotcfg_setup.sh ---

# --- 1. Initialization & Variables ---
init_vars() {
    repo_url="https://github.com/Drauku/dotcfg.git"
    repo_dir="$HOME/.dotfiles"
    this_script="$(realpath "$0")"
    backup_dir="$HOME/.dotfiles_backup/backup_$(date +%Y%m%d_%H%M%S)"

    standard_pkgs=("common")
    optional_pkgs=("docker" "server" "gaming")
    dependencies=("git" "stow")
    optional_apps=("fastfetch")

    # Colors and Formatting using tput fallback
    if [ -t 1 ] && command -v tput >/dev/null; then
        red=$(tput setaf 1); grn=$(tput setaf 2); ylw=$(tput setaf 3)
        blu=$(tput setaf 4); mgn=$(tput setaf 5); cyn=$(tput setaf 6)
        bld=$(tput bold); itx=$(tput sitm); uln=$(tput smul); rst=$(tput sgr0)
    else
        red=""; grn=""; ylw=""; blu=""; mgn=""; bld=""; itx=""; uln=""; rst=""
    fi
}

# --- 2. System Intelligence ---
check_env() {
    # Determine OS/Environment
    if [ -f /etc/os-release ]; then
        os_id=$(grep -w "ID" /etc/os-release | cut -d= -f2 | tr -d '"')
        [ -f /usr/bin/pveversion ] && os_id="proxmox"
    fi

    # Determine root command
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            root_cmd="sudo"
        else
            echo -e "${red}Error: This script requires root privileges, but sudo is not installed.${rst}"
            exit 1
        fi
    else
        root_cmd=""
    fi

    # Determine Package Manager
    if command -v dnf >/dev/null 2>&1; then
        pkg_mgr="$root_cmd dnf install -y"
    elif command -v apt-get >/dev/null 2>&1; then
        pkg_mgr="$root_cmd apt-get update && $root_cmd apt-get install -y"
    elif command -v pacman >/dev/null 2>&1; then
        pkg_mgr="$root_cmd pacman -S --noconfirm"
    else
        pkg_mgr=""
    fi
}

# --- 3. Dependency Management ---
install_dependencies() {
    if [ -n "$pkg_mgr" ]; then
        for pkg in "${dependencies[@]}"; do
            if ! command -v "$pkg" >/dev/null 2>&1; then
                echo -e "${ylw}Attempting to install $pkg...${rst}"
                eval "$pkg_mgr $pkg"
            fi
        done
    fi

    # Verify dependencies are met
    for pkg in "${dependencies[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            echo -e "${red}Error: $pkg is not installed. Please install manually.${rst}"
            exit 1
        fi
    done
}

# --- 4. Repository Management ---
manage_repo() {
    if [ ! -d "$repo_dir" ]; then
        echo -e "${ylw}Cloning repository...${rst}"
        git clone "$repo_url" "$repo_dir"
    else
        echo -e "${blu}Updating repository...${rst}"
        if ! (cd "$repo_dir" && git pull); then
            echo -e "${red}Error: git pull failed in $repo_dir (likely local changes conflicting with upstream).${rst}"
            echo -e "${red}Resolve or stash the local changes in $repo_dir, then re-run this script.${rst}"
            exit 1
        fi
    fi

    # Install Git Runner (Post-Merge Hook)
    local hook_file="$repo_dir/.git/hooks/post-merge"
    if [ -d "$repo_dir/.git" ] && [ ! -f "$hook_file" ]; then
        echo -e "${blu}Installing Git post-merge runner...${rst}"

        # Quoted 'EOF' ensures variables are evaluated at runtime, not creation time
        cat << 'EOF' > "$hook_file"
#!/bin/bash
repo_root=$(git rev-parse --show-toplevel)
setup_script="$repo_root/dotcfg_setup.sh"
if [ -f "$setup_script" ]; then
    echo -e ">> Git merge detected. Running dotcfg_setup.sh..."
    bash "$setup_script"
fi
EOF
        chmod +x "$hook_file"
    fi

    # Initialize Secrets
    if [ ! -f "$HOME/.bash_secrets" ]; then
        echo -e "${ylw}Initializing .bash_secrets...${rst}"
        echo -e "# Private environment variables" > "$HOME/.bash_secrets"
    fi
}

# --- 5. Core Stow Logic ---
safe_stow() {
    local package=$1
    [ ! -d "$repo_dir/$package" ] && return

    # repo_root is statically defined now since we know it's in $repo_dir
    local repo_root="$repo_dir"

    echo -e "${blu}Stowing ${cyn}$package${rst}..."
    (
        cd "$repo_dir/$package" || exit
        for item in .??* *; do
            [ ! -e "$item" ] && continue
            local target="$HOME/$item"

            # Backup real files
            if [ -e "$target" ] && [ ! -L "$target" ]; then
                echo -e "${mgn}Backing up $target to $backup_dir${rst}"
                mkdir -p "$backup_dir"
                mv "$target" "$backup_dir/"
            fi

            # Correct/Broken Link Handling
            if [ -L "$target" ]; then
                local link_dest; link_dest=$(readlink "$target")
                local absolute_dest; absolute_dest=$(readlink -f "$target")

                if [[ "$absolute_dest" != "$repo_root"* ]]; then
                    local new_path="${repo_root}/${package}/${item}"
                    echo -e "${ylw}Found incorrect or broken link: ${cyn}$item${rst}"
                    echo -e "  Current: ${red}${link_dest:-[BROKEN]}${rst}"
                    echo -e "  Correct: ${grn}$new_path${rst}"

                    read -p "  Replace with updated link? (Y/n): " -n 1 -r < /dev/tty
                    [[ -n "$REPLY" ]] && echo

                    case "$REPLY" in
                        [Nn]*) echo -e "${mgn}Skipping $item...${rst}\n"; continue ;;
                        *) [[ -z "$REPLY" ]] && echo; rm "$target" ;;
                    esac
                fi
            fi
        done
    )
    # Execute stow from inside the repo_dir to ensure proper pathing
    (cd "$repo_dir" && stow -v -R -t "$HOME" "$package")
}

# --- 6. Selection UI ---
select_packages() {
    selected_pkgs=("${standard_pkgs[@]}")

    # Add OS-specific package automatically
    [ -d "$repo_dir/$os_id" ] && selected_pkgs+=("$os_id")

    [[ -z "${optional_pkgs[*]}" ]] && return

    echo -e "\n${blu}${bld}--- Optional package selection ---${rst}\n"
    for pkg in "${optional_pkgs[@]}"; do
        [ ! -d "$repo_dir/$pkg" ] && continue
        read -p "${ylw}Stow ${cyn}$pkg${rst}${ylw} configs?${rst} (y/N): " -n 1 -r < /dev/tty; echo

        case "$REPLY" in
            [Yy]*)
                if [[ "$pkg" == "docker" && -e "/usr/local/bin/csm" ]]; then
                    echo -e "${ylw}>> CSM detected. Skipping legacy docker stow.${rst}"
                else
                    selected_pkgs+=("$pkg")
                fi
                ;;
            *) continue ;;
        esac
    done
}

# --- 7. Deployment Execution ---
execute_deployment() {
    echo -e "\n${blu}${bld}--- Deployment Plan ---${rst}"
    echo -e "${ylw}The following packages will be Stow(ed)${rst}:"
    echo -e " - ${grn}$(IFS=', '; echo "${selected_pkgs[*]}") ${rst}"

    read -p "${mgn}Proceed with deployment? (y/N): ${rst}" -n 1 -r < /dev/tty; echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo -e "${red}Deployment aborted.${rst}"
        exit 0
    fi

    for pkg in "${selected_pkgs[@]}"; do
        safe_stow "$pkg"
    done

    [ -d "$backup_dir" ] && echo -e "Backups saved to: ${mgn}$backup_dir${rst}"
    echo -e "\nTo finish: ${ylw}source ~/.bashrc${rst}"
    echo -e "\n${grn}${bld}--- Deployment Complete ---${rst}"
}

# --- Main Runtime ---
main() {
    echo -e "\n${blu}${bld}>>> Launching modular dotfile setup using Stow >>>${rst}\n"
    init_vars
    check_env
    install_dependencies
    manage_repo
    select_packages
    execute_deployment
}

# Execute main function with all script arguments
main "$@"

# --- Final cleanup (self-destruct) ---
# if [[ "$this_script" != "$repo_script" ]] && [ -d "$repo_dir" ]; then
#     read -p "${ylw}Clean up temporary setup script? (y/N): ${rst}" -n 1 -r < /dev/tty; echo
#     if [[ $REPLY =~ ^[Yy]$ ]]; then
#         rm -- "$0" && echo -e "${grn}Temporary script ${red}removed${rst}.\n"
#     else
#         echo -e "${mgn}Skipping cleanup. Script preserved at: ${cyn}$(realpath "$0")${rst}\n"
#     fi
# fi
