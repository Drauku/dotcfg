#!/usr/bin/env bash
## Install zsh, oh-my-zsh, powerlevel10k, MesloLGS Nerd Fonts, and zsh plugins.
## Supports Arch/CachyOS (pacman) and Debian/Ubuntu (apt).
##
## Bundled with the dotcfg 'zsh' stow package. The custom prompt config
## (.p10k.zsh) lives alongside this script and is normally symlinked into
## ~/.p10k.zsh by stow; this installer only provisions the surrounding
## environment (packages, fonts, plugins, and ~/.zshrc wiring).
##
## Can also be run standalone:
##   bash zsh/install-zsh-p10k.sh

# Directory this script lives in (the stow package root), so the local
# .p10k.zsh can be found whether run via dotcfg or directly.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PKG_MANAGER=""
PKG_INSTALL=""

## ─── Package manager detection ─────────────────────────────────────────────

detect_pkg_manager() {
    if command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        if command -v yay >/dev/null 2>&1; then
            PKG_INSTALL="yay -S --needed --noconfirm"
        elif command -v paru >/dev/null 2>&1; then
            PKG_INSTALL="paru -S --needed --noconfirm"
        else
            PKG_INSTALL="sudo pacman -S --needed --noconfirm"
        fi
        printf "\n Detected: Arch/CachyOS (pacman)\n"
    elif command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt install -y"
        printf "\n Detected: Debian/Ubuntu (apt)\n"
    else
        printf "\n ERROR: Unsupported package manager. Install packages manually.\n" >&2
        exit 1
    fi
}

## ─── Package installation ───────────────────────────────────────────────────

# Echo the subset of "$@" that isn't installed yet, one per line. `--needed` and
# `apt install` are both no-ops for already-present packages, but only *after*
# sudo has been acquired — so re-running this installer prompted for a password
# just to do nothing. Checking first lets the caller skip the privileged call.
missing_packages() {
    local pkg
    for pkg in "$@"; do
        case "$PKG_MANAGER" in
            pacman)
                pacman -Q "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
                ;;
            apt)
                # dpkg -s succeeds for removed-but-not-purged packages, so match
                # the full status rather than just the exit code.
                dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null \
                    | grep -q '^install ok installed$' || printf '%s\n' "$pkg"
                ;;
        esac
    done
}

install_packages() {
    local missing=()
    printf "\n Installing packages...\n"
    case "$PKG_MANAGER" in
        pacman)
            # All packages available in Arch repos or CachyOS repos.
            # On stock Arch, oh-my-zsh-git is in the AUR — requires yay or paru.
            mapfile -t missing < <(missing_packages zsh git curl fontconfig \
                oh-my-zsh-git zsh-theme-powerlevel10k ttf-meslo-nerd \
                zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search)
            [ ${#missing[@]} -eq 0 ] && { printf "  All packages already installed, skipping.\n"; return 0; }
            printf "  Missing: %s\n" "${missing[*]}"
            $PKG_INSTALL "${missing[@]}"
            ;;
        apt)
            mapfile -t missing < <(missing_packages curl fontconfig git zsh)
            [ ${#missing[@]} -eq 0 ] && { printf "  All packages already installed, skipping.\n"; return 0; }
            printf "  Missing: %s\n" "${missing[*]}"
            # Only refresh the index — do NOT `apt upgrade` the whole system;
            # a prompt installer should not trigger a mass system upgrade.
            sudo apt update -y && $PKG_INSTALL "${missing[@]}"
            ;;
    esac
}

## ─── Fonts (Debian/Ubuntu only — Arch uses ttf-meslo-nerd package) ──────────

install_fonts() {
    [ "$PKG_MANAGER" = "apt" ] || return 0
    printf "\n Installing MesloLGS Nerd Fonts...\n"
    local font_dir="${HOME}/.local/share/fonts"
    mkdir -p "$font_dir"
    local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
    for encoded in "MesloLGS%20NF%20Regular.ttf" "MesloLGS%20NF%20Bold.ttf" \
                   "MesloLGS%20NF%20Italic.ttf" "MesloLGS%20NF%20Bold%20Italic.ttf"; do
        local decoded="${encoded//%20/ }"
        curl -fsSL "${base}/${encoded}" -o "${font_dir}/${decoded}"
    done
    fc-cache -f -v
}

## ─── oh-my-zsh (Debian/Ubuntu only — Arch uses system package) ──────────────

install_omz() {
    [ "$PKG_MANAGER" = "apt" ] || return 0
    if [ -d "${HOME}/.oh-my-zsh" ]; then
        printf "\n oh-my-zsh already installed, skipping.\n"
        return 0
    fi
    printf "\n Installing oh-my-zsh...\n"
    # RUNZSH=no prevents spawning a new interactive shell mid-script.
    # CHSH=no skips the chsh call (we handle it separately below).
    # KEEP_ZSHRC=yes stops the installer from moving the user's existing
    # ~/.zshrc to ~/.zshrc.pre-oh-my-zsh and replacing it with its template;
    # we edit the existing ~/.zshrc ourselves in configure_zshrc().
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

## ─── Powerlevel10k theme (Debian/Ubuntu only) ───────────────────────────────

install_p10k_theme() {
    [ "$PKG_MANAGER" = "apt" ] || return 0
    local theme_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ -d "$theme_dir" ]; then
        printf "\n Powerlevel10k already installed, skipping.\n"
        return 0
    fi
    printf "\n Installing Powerlevel10k theme...\n"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
}

## ─── Plugins (Debian/Ubuntu only — Arch uses system packages) ───────────────

install_plugins() {
    [ "$PKG_MANAGER" = "apt" ] || return 0
    printf "\n Installing zsh plugins...\n"
    local plugin_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"
    for entry in \
        "agkozak/zsh-z:zsh-z" \
        "zsh-users/zsh-autosuggestions:zsh-autosuggestions" \
        "zsh-users/zsh-syntax-highlighting:zsh-syntax-highlighting"; do
        local repo="${entry%%:*}"
        local name="${entry##*:}"
        if [ -d "${plugin_dir}/${name}" ]; then
            printf "  %s already installed, skipping.\n" "$name"
        else
            git clone "https://github.com/${repo}" "${plugin_dir}/${name}"
        fi
    done
}

## ─── Configure ~/.zshrc ─────────────────────────────────────────────────────

# Add a line to ~/.zshrc, inserting it just before the first `source …oh-my-zsh.sh`
# so OMZ sees it; if that source line is absent, append at EOF. No-op when the
# `match` substring is already present on a non-comment line (idempotent). We
# add OMZ plugins via `plugins+=(…)` rather than editing the plugins=(…) array,
# so this stays correct regardless of single- vs multi-line array formatting.
_zshrc_add_line() {
    local line="$1" match="$2"
    grep -v '^[[:space:]]*#' ~/.zshrc | grep -qF "$match" && return 0
    if grep -q 'source.*oh-my-zsh.sh' ~/.zshrc; then
        awk -v ins="$line" 'BEGIN{d=0} d==0 && /oh-my-zsh\.sh/ {print ins; d=1} {print}' \
            ~/.zshrc > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
    else
        printf '%s\n' "$line" >> ~/.zshrc
    fi
}

configure_zshrc() {
    printf "\n Configuring ~/.zshrc...\n"

    # Backup original once
    [ ! -f ~/.zshrc.original ] && [ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.original
    [ -f ~/.zshrc ] || touch ~/.zshrc

    # Guarantee a trailing newline so `>>` appends never merge onto the last line.
    [ -s ~/.zshrc ] && [ -n "$(tail -c1 ~/.zshrc)" ] && printf '\n' >> ~/.zshrc

    case "$PKG_MANAGER" in
        pacman)
            if grep -q 'cachyos-config' ~/.zshrc; then
                # CachyOS: the instant-prompt block and the p10k source line are
                # already provided via cachyos-zsh-config, so skip .zshrc
                # restructuring entirely (including the shared post-case blocks
                # below) to avoid duplicating instant-prompt initialization.
                printf "  CachyOS zsh config detected — skipping .zshrc restructuring.\n"
                return 0
            else
                # Plain Arch: oh-my-zsh is at /usr/share/oh-my-zsh (system-wide).
                # The powerlevel10k theme ships at /usr/share/zsh-theme-powerlevel10k/
                # (NOT under OMZ's themes dir), so it must be sourced directly rather
                # than selected via ZSH_THEME. Plugins live in /usr/share/zsh/plugins/.
                # export ZSH and the plugins must precede the OMZ source line.
                _zshrc_add_line 'export ZSH=/usr/share/oh-my-zsh' 'ZSH=/usr/share/oh-my-zsh'
                _zshrc_add_line 'plugins+=(git)' 'plugins+=(git'

                grep -q 'source.*oh-my-zsh.sh' ~/.zshrc || \
                    printf '\nsource $ZSH/oh-my-zsh.sh\n' >> ~/.zshrc

                # The theme must be sourced AFTER oh-my-zsh.sh, so append at EOF.
                grep -qF '/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' ~/.zshrc || \
                    printf 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme\n' >> ~/.zshrc

                for plugin_file in \
                    "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
                    "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
                    "/usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"; do
                    [ -f "$plugin_file" ] || continue
                    grep -qF "$plugin_file" ~/.zshrc || \
                        printf 'source %s\n' "$plugin_file" >> ~/.zshrc
                done
            fi
            ;;
        apt)
            # On a box that already had a ~/.zshrc, oh-my-zsh ran with
            # KEEP_ZSHRC=yes and did NOT write its template, so we inject the OMZ
            # bootstrap ourselves. On a truly fresh box OMZ *does* write its
            # template (plugins=(git), ZSH_THEME, source line). Either way, the
            # helpers below converge to the same correct, ordered result:
            # export ZSH / ZSH_THEME / plugins all precede the OMZ source line.
            _zshrc_add_line 'export ZSH="$HOME/.oh-my-zsh"' 'export ZSH='

            # Drop any existing ZSH_THEME= line (whatever the quoting or position)
            # and re-add it before the OMZ source line so it is set in time.
            sed -i '/^ZSH_THEME=/d' ~/.zshrc
            _zshrc_add_line 'ZSH_THEME="powerlevel10k/powerlevel10k"' 'ZSH_THEME='

            # Enable the cloned plugins via `plugins+=(…)` (format-agnostic; works
            # whether the template's plugins=(git) is single- or multi-line).
            _zshrc_add_line 'plugins+=(zsh-z zsh-autosuggestions zsh-syntax-highlighting)' 'plugins+=(zsh-z'

            grep -q 'source.*oh-my-zsh.sh' ~/.zshrc || \
                printf '\nsource $ZSH/oh-my-zsh.sh\n' >> ~/.zshrc
            ;;
    esac

    # Prepend instant-prompt block if missing (idempotent for both distros)
    if ! grep -q 'p10k-instant-prompt' ~/.zshrc; then
        {
            cat <<'BLOCK'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

BLOCK
            cat ~/.zshrc
        } > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
    fi

    # Append wizard-disable flag and p10k source line if missing
    if ! grep -q 'p10k.zsh' ~/.zshrc; then
        printf '\nPOWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true\n' >> ~/.zshrc
        printf '\n# To customize prompt, run '"'"'p10k configure'"'"' or edit ~/.p10k.zsh.\n' >> ~/.zshrc
        printf '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n' >> ~/.zshrc
    fi
}

## ─── Install custom p10k config ─────────────────────────────────────────────

install_p10k_config() {
    # When deployed via dotcfg, stow already symlinks ~/.p10k.zsh to the repo
    # copy, so there is nothing to do. When run standalone, copy the local
    # config that ships next to this script; only fall back to the network if
    # that is somehow missing.
    if [ -L ~/.p10k.zsh ]; then
        local link_target managed_target
        link_target="$(readlink -f ~/.p10k.zsh 2>/dev/null)"
        managed_target="$(readlink -f "${SCRIPT_DIR}/.p10k.zsh" 2>/dev/null)"
        if [ -n "$link_target" ] && [ "$link_target" = "$managed_target" ]; then
            printf "\n ~/.p10k.zsh is the managed stow symlink — leaving it in place.\n"
            return 0
        fi
        # Dangling or foreign symlink — remove it and lay down a real config.
        printf "\n ~/.p10k.zsh is a broken/unmanaged symlink — replacing it.\n"
        rm -f ~/.p10k.zsh
    fi

    printf "\n Installing custom p10k config...\n"
    [ -f ~/.p10k.zsh ] && [ ! -f ~/.p10k.zsh.original ] && cp ~/.p10k.zsh ~/.p10k.zsh.original

    if [ -f "${SCRIPT_DIR}/.p10k.zsh" ]; then
        cp "${SCRIPT_DIR}/.p10k.zsh" ~/.p10k.zsh
    else
        curl -fsSL \
            https://raw.githubusercontent.com/Drauku/install-zsh-p10k/main/.p10k.zsh.custom \
            -o ~/.p10k.zsh
    fi
}

## ─── Set default shell ──────────────────────────────────────────────────────

set_default_shell() {
    local zsh_path current
    zsh_path="$(command -v zsh)" || return 0
    # Compare against the passwd entry, not $SHELL: $SHELL is inherited from the
    # environment and can spell the same binary differently than `command -v`
    # (/bin/zsh vs /usr/bin/zsh on merged-/usr distros), which made this guard
    # never match — so chsh ran, and prompted for a password, on every re-run.
    # readlink -f collapses that difference.
    current="$(getent passwd "$(id -un)" | cut -d: -f7)"
    if [ "$(readlink -f "$current")" = "$(readlink -f "$zsh_path")" ]; then
        printf "\n zsh is already the default shell, skipping.\n"
        return 0
    fi
    printf "\n Set zsh as default shell? [Y/n] "
    read -r input
    case "${input:-y}" in
        [yY]|[yY][eE][sS])
            chsh -s "$zsh_path"
            ;;
    esac
}

## ─── Main ───────────────────────────────────────────────────────────────────

detect_pkg_manager
install_packages || { printf "\n ERROR: package installation failed — aborting.\n" >&2; exit 1; }
install_fonts
install_omz
install_p10k_theme
install_plugins
configure_zshrc
install_p10k_config
set_default_shell

printf "\n ZSH, Powerlevel10k, and plugins are installed.\n"
printf "  Restart your terminal or run 'exec zsh' to apply changes.\n\n"
