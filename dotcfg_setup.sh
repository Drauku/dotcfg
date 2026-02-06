#!/bin/bash
# --- setup.sh ---

# --- Variable Definitions ---
repo_url="https://github.com/Drauku/dotcfg.git"
repo_dir="$HOME/dotcfg"
repo_script="$repo_dir/dotcfg_setup.sh"
this_script="$(realpath "$0")"
backup_dir="$HOME/.dotfiles_backup/backup_$(date +%Y%m%d_%H%M%S)"
standard_pkgs=("common")
optional_pkgs=("docker" "server" "gaming")

if [ -t 1 ] && command -v tput >/dev/null; then
    red=$(tput setaf 1); grn=$(tput setaf 2); ylw=$(tput setaf 3)
    blu=$(tput setaf 4); mgn=$(tput setaf 5); cyn=$(tput setaf 6)
    bld=$(tput bold); itx=$(tput sitm); uln=$(tput smul); rst=$(tput sgr0)
else
    red=""; grn=""; ylw=""; blu=""; mgn=""; bld=""; itx=""; uln=""; rst=""
fi

# Identify OS for recommendation
[ -f /etc/os-release ] && os_id=$(grep -w "ID" /etc/os-release | cut -d= -f2 | tr -d '"')

# Script Header
echo -e "\n${blu}${bld}>>> Launching modular dotfile setup using Stow >>>${rst}\n"

# Dependency Check (Multi-Distro)
if command -v dnf >/dev/null 2>&1; then
    pkg_mgr="sudo dnf install -y"
elif command -v apt-get >/dev/null 2>&1; then
    pkg_mgr="sudo apt-get update && sudo apt-get install -y"
elif command -v pacman >/dev/null 2>&1; then
    pkg_mgr="sudo pacman -S --noconfirm"
fi

for pkg in git stow; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        echo "${ylw}Installing $pkg...${rst}"
        eval "$pkg_mgr $pkg"
    fi
done

# Repo Management
if [ ! -d "$repo_dir" ]; then
    echo "${ylw}"
    git clone "$repo_url" "$repo_dir"
    echo "${rst}"
else
    echo "${blu}Updating repository...${rst}"
    cd "$repo_dir" && git pull
fi
cd "$repo_dir" || exit 1

# Install Git Runner (Post-Merge Hook installed on each host)
hook_file="$repo_dir/.git/hooks/post-merge"
if [ -d ".git" ] && [ ! -f "$hook_file" ]; then
    echo "${blu}Installing Git post-merge runner...${rst}"
    cat << 'EOF' > "$hook_file"
#!/bin/bash
# Automatically runs setup after a successful git pull
setup_script="$HOME/dotcfg/dotcfg_setup.sh"
if [ -f "$setup_script" ]; then
    echo ">> Git merge detected. Running dotcfg_setup.sh..."
    bash "$setup_script"
fi
EOF
    chmod +x "$hook_file"
fi

# Initialize Secrets (Local Only)
if [ ! -f "$HOME/.bash_secrets" ]; then
    echo "${ylw}Initializing .bash_secrets...${rst}"
    echo "# Private environment variables" > "$HOME/.bash_secrets"
fi

# Smart Backup & Stow Function
safe_stow() {
    local package=$1
    # Skip if folder doesn't exist
    [ ! -d "$package" ] && return

    echo "${blu}Stowing ${cyn}$package${rst}..."
    (
        cd "$package" || exit
        # Iterate over all items (including hidden ones)
        for item in .??* *; do
            # Skip if the glob didn't match anything
            [ ! -e "$item" ] && continue

            target="$HOME/$item"
            # If target exists and is NOT a symlink, back it up
            if [ -e "$target" ] && [ ! -L "$target" ]; then
                # echo "${mgn}Backing up $target to $backup_dir${rst}"
                mkdir -p "$backup_dir"
                mv "$target" "$backup_dir/"
            fi
        done
    )
    # Stow indicated package
    stow -v -R "$package"
}

# Set selected packages:
selected_pkgs=("${standard_pkgs[@]}")

# Automatically add the OS-specific folder if it exists
if [ -d "$os_id" ]; then selected_pkgs+=("$os_id"); fi

# Package selection
echo "${blu}${bld}--- Optional packages ---${rst}"

# Optional packages
for pkg in "${optional_pkgs[@]}"; do
    [ ! -d "$pkg" ] && continue # Skip if folder isn't in repo
    read -p "${ylw}Stow ${cyn}$pkg${rst}${ylw}? (y/N): ${rst}" -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Only check CSM for the docker package
        if [[ "$pkg" == "docker" ]] && [ -d "$HOME/git/container-stack-manager" ]; then
            echo "${red}>> CSM detected. Skipping legacy docker stow.${rst}"
            continue
        fi
        selected_pkgs+=("$pkg")
    fi
done

# Deployment confirmation
echo -e "\n${blu}${bld}--- Deployment Plan ---${rst}"
echo "${ylw}The following packages will be Stow(ed)${rst}:"
echo "  - ${grn}$(echo "${selected_pkgs[@]}" | sed 's/ /, /g')${rst}"
read -p "${mgn}Proceed with deployment? (y/N): ${rst}" -n 1 -r; echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "${red}Deployment aborted.${rst}"
    exit 0
fi

for pkg in "${selected_pkgs[@]}"; do
    safe_stow "$pkg"
done

[ -d "$backup_dir" ] && echo "Backups saved to: ${mgn}$backup_dir${rst}"

echo "To finish: ${ylw}source ~/.bashrc${rst}"
echo -e "\n${grn}${bld}--- Deployment Complete ---${rst}"

# --- Final cleanup (self-destruct) ---
if [[ "$this_script" != "$repo_script" ]] && [ -d "$repo_dir" ]; then
    read -p "\n${ylw}Clean up temporary setup script? (y/N): ${rst}\n" -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -- "$0" && echo -e "\n${grn}Temporary script ${red}removed${rst}."
    else
        echo -e "\n${mgn}Skipping cleanup. Script preserved at: ${cyn}$(realpath "$0")${rst}"
    fi
fi
