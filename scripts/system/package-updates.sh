#!/bin/bash

#===============================================================================
# Package Updates Checker
# ~/.config/scripts/system/package-updates.sh
# Description: Checks for available package updates using checkupdates-with-aur
# Author: saatvik333
# Version: 2.0
# Dependencies: checkupdates-with-aur, notify-send
#===============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# --- Configuration ---
readonly SCRIPT_NAME="${0##*/}"
readonly LOCK_FILE="/tmp/${SCRIPT_NAME%.sh}.lock"
readonly THRESHOLD_YELLOW=25
readonly THRESHOLD_RED=100

# --- Functions ---
check_database_locks() {
    local -r pacman_lock="/var/lib/pacman/db.lck"
    local -r checkup_lock="${TMPDIR:-/tmp}/checkup-db-${UID}/db.lck"
    local -r timeout=30
    local elapsed=0

    while [[ -f "$pacman_lock" || -f "$checkup_lock" ]]; do
        if (( elapsed >= timeout )); then
            echo '{"tooltip": "Database locked - try again later", "class": "transparent"}'
            exit 1
        fi
        sleep 1
        ((elapsed++))
    done
}

get_update_count() {
    local updates
    if ! updates=$(checkupdates-with-aur 2>/dev/null | wc -l); then
        log_error "Failed to check for updates"
        echo '{"tooltip": "Error checking updates", "class": "transparent"}'
        exit 1
    fi
    echo "$updates"
}

determine_css_class() {
    local -r updates=$1
    
    if (( updates == 0 )); then
        echo "transparent"
    elif (( updates <= THRESHOLD_YELLOW )); then
        echo "green"
    elif (( updates <= THRESHOLD_RED )); then
        echo "yellow"
    else
        echo "red"
    fi
}

output_waybar_json() {
    local -r updates=$1
    local -r css_class=$2
    
    if (( updates > 0 )); then
        printf '{"text": "%d", "tooltip": "%d packages require updates", "class": "%s"}\n' \
            "$updates" "$updates" "$css_class"
    else
        printf '{"text": "0", "tooltip": "System is up to date", "class": "transparent"}\n'
    fi
}

main() {
    acquire_lock "$LOCK_FILE" "$SCRIPT_NAME"
    
    # Validate dependencies
    if ! command -v checkupdates-with-aur >/dev/null 2>&1; then
        send_notification "Package Updates" "Dependency Missing" \
            "checkupdates-with-aur not found. Install pacman-contrib." "critical" "dialog-warning"
        echo '{"tooltip": "checkupdates-with-aur not found", "class": "transparent"}'
        exit 1
    fi
    
    check_database_locks
    
    local updates css_class
    updates=$(get_update_count)
    css_class=$(determine_css_class "$updates")
    
    output_waybar_json "$updates" "$css_class"
    
    # Send notification for significant updates
    if (( updates >= THRESHOLD_YELLOW )); then
        send_notification "Package Updates" "Updates Available" \
            "$updates packages can be updated" "normal" "system-software-update"
    fi
}

# --- Script Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi