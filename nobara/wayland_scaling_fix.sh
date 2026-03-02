#!/usr/bin/env bash

# ==============================================================================
# wayland-scaling-fix.sh
# Fixes Wayland scaling for Electron/Chromium apps on Nobara/KDE Plasma.
# Forces apps to run natively on Wayland to resolve mouse offset and blur.
# ==============================================================================

# --- Color Setup (tput fallback) ----------------------------------------------
_safe_tput() { tput "$@" 2>/dev/null; }
red=$(_safe_tput setaf 1) || red='\033[31m'
grn=$(_safe_tput setaf 2) || grn='\033[32m'
ylw=$(_safe_tput setaf 3) || ylw='\033[33m'
blu=$(_safe_tput setaf 4) || blu='\033[34m'
bld=$(_safe_tput bold)    || bld='\033[1m'
rst=$(_safe_tput sgr0)    || rst='\033[0m'

# --- Constants ----------------------------------------------------------------
# These flags enable native Wayland rendering and window decorations in Electron/Chromium
readonly wayland_flags="--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations"
readonly local_app_dir="$HOME/.local/share/applications"
readonly system_app_dirs=("/usr/share/applications" "/var/lib/flatpak/exports/share/applications")
readonly flatpak_env_var="ELECTRON_OZONE_PLATFORM_HINT=auto"

# Default app list (used with -a / -r)
readonly -a target_apps=("vivaldi" "brave" "codium" "heroic" "element" "signal" "vesktop")

# --- Helpers ------------------------------------------------------------------
log_info() { echo "${blu}${bld}[INFO]${rst}  $*"; }
log_done() { echo "${grn}${bld}[DONE]${rst}  $*"; }
log_warn() { echo "${ylw}${bld}[WARN]${rst}  $*"; }
log_fail() { echo "${red}${bld}[FAIL]${rst}  $*" >&2; }

usage() {
    cat <<EOF
${bld}Usage:${rst} $(basename "$0") [OPTIONS]

${bld}Options:${rst}
  -a            Apply fixes to all default apps + Flatpak override
  -r            Revert fixes for all default apps + Flatpak override
  -A <appname>  Apply fix to a single named app (e.g. -A spotify)
  -R <appname>  Revert fix for a single named app
  -s            Scan and list detected Electron/Chromium apps
  -S            Scan and auto-fix all detected apps (skips already-patched)
  -h            Show this help message
EOF
}

# Locates the system .desktop file for a given app name
find_system_desktop() {
    local app="$1"
    local dir result
    for dir in "${system_app_dirs[@]}"; do
        result=$(find "$dir" -name "*${app}*.desktop" 2>/dev/null | head -n 1)
        [[ -n "$result" ]] && echo "$result" && return
    done
}

# --- Flatpak Management -------------------------------------------------------
apply_flatpak_fix() {
    if ! command -v flatpak >/dev/null; then
        log_warn "flatpak not found — skipping Flatpak fix."
        return
    fi
    log_info "Applying Flatpak Wayland environment override..."
    if flatpak override --user --env="$flatpak_env_var"; then
        log_done "Flatpak override applied: $flatpak_env_var"
    else
        log_fail "Failed to apply Flatpak override."
    fi
}

revert_flatpak_fix() {
    if ! command -v flatpak >/dev/null; then
        return
    fi
    log_info "Removing Flatpak Wayland environment override..."
    local env_key="${flatpak_env_var%%=*}"
    flatpak override --user --unset-env="$env_key"
    log_done "Flatpak override removed."
}

# --- Desktop File Patching ----------------------------------------------------
apply_single_app() {
    local app="$1"
    local file_path basename local_file

    file_path=$(find_system_desktop "$app")
    if [[ -z "$file_path" ]]; then
        log_warn "No system .desktop file found for '$app' — skipping."
        return
    fi

    basename=$(basename "$file_path")
    local_file="$local_app_dir/$basename"

    # Create local override copy
    mkdir -p "$local_app_dir"
    cp "$file_path" "$local_file"

    # Fix: Use double-dash -- to ensure grep doesn't treat flag as an option
    if grep -q -- "ozone-platform-hint" "$local_file"; then
        log_warn "$basename already patched — skipping."
        return
    fi

    # Robust Sed:
    # 1. Strip existing %U or %F temporarily
    # 2. Append flags and re-add %U at the end of Exec line
    sed -i '/^Exec=/ s/[[:space:]]*%[UF]//g' "$local_file"
    sed -i "/^Exec=/ s|$| $wayland_flags %U|" "$local_file"

    log_done "Patched: $basename"
}

revert_single_app() {
    local app="$1"
    local file_path basename local_file

    file_path=$(find_system_desktop "$app")
    [[ -z "$file_path" ]] && return

    basename=$(basename "$file_path")
    local_file="$local_app_dir/$basename"

    if [[ -f "$local_file" ]]; then
        rm "$local_file"
        log_done "Removed local override: $basename"
    fi
}

# --- Scanner Logic ------------------------------------------------------------
scan_for_apps() {
    local auto_fix="${1:-false}"
    log_info "Scanning for Electron/Chromium-based apps..."

    local dir file exec_bin binary_path found_count=0
    local -a search_dirs=("/usr/share/applications")

    # Markers to identify Electron/Chromium binaries
    # FIX: Added double-dash -- to grep calls to handle markers starting with '-'
    local -a markers=("electron" "icudtl.dat" "v8_context_snapshot" "--ozone-platform")

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for file in "$dir"/*.desktop; do
            [[ -f "$file" ]] || continue

            # Extract the binary name from the Exec line
            exec_bin=$(grep -m1 "^Exec=" "$file" | sed 's/^Exec=//; s/ .*//' | xargs)
            binary_path=$(command -v "$exec_bin" 2>/dev/null)

            [[ -z "$binary_path" || ! -f "$binary_path" ]] && continue

            for marker in "${markers[@]}"; do
                # Double-dash -- prevents "unrecognized option" error for markers like --ozone-platform
                if strings -a "$binary_path" 2>/dev/null | grep -qi -- "$marker"; then
                    local bname=$(basename "$file")
                    local app_name="${bname%.desktop}"

                    if grep -q "ozone-platform-hint" "$local_app_dir/$bname" 2>/dev/null; then
                        printf "${grn}%-30s [Already Patched]${rst}\n" "$app_name"
                    else
                        printf "${ylw}%-30s [Detected: %s]${rst}\n" "$app_name" "$marker"
                        [[ "$auto_fix" == true ]] && apply_single_app "$app_name"
                    fi
                    ((found_count++))
                    break
                fi
            done
        done
    done
    log_info "Scan complete. Found $found_count potential apps."
}

# --- Entry Point --------------------------------------------------------------
main() {
    [[ $# -eq 0 ]] && { usage; exit 0; }

    while getopts ":arA:R:sS h" opt; do
        case "$opt" in
            a) apply_flatpak_fix; for a in "${target_apps[@]}"; do apply_single_app "$a"; done ;;
            r) revert_flatpak_fix; for a in "${target_apps[@]}"; do revert_single_app "$a"; done ;;
            A) apply_single_app "$OPTARG" ;;
            R) revert_single_app "$OPTARG" ;;
            s) scan_for_apps false ;;
            S) apply_flatpak_fix; scan_for_apps true ;;
            h) usage; exit 0 ;;
            \?) log_fail "Unknown option: -${OPTARG}"; usage; exit 1 ;;
        esac
    done
}

main "$@"
