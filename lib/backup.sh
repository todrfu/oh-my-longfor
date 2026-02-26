#!/usr/bin/env bash
# oh-my-longfor backup and rollback system
# Provides: timestamped config backups, rollback to previous config
set -euo pipefail

# shellcheck source=lib/common.sh
# source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Default OML home (should be sourced from common.sh)
OML_HOME="${OML_HOME:-$HOME/.oml}"
OML_MAX_BACKUPS=5

# Create a timestamped backup of current config files before regeneration
# Usage: oml_backup_create
oml_backup_create() {
  local config_dir="${OML_HOME}/config"
  local backups_dir="${OML_HOME}/backups"
  local timestamp
  timestamp="$(date -u '+%Y-%m-%d-%H%M%S')"
  local backup_dir="${backups_dir}/${timestamp}"

  # Nothing to back up if config doesn't exist yet
  if [ ! -d "$config_dir" ]; then
    return 0
  fi

  local has_files=false
  for f in "${config_dir}/opencode.json" "${config_dir}/oh-my-opencode.jsonc" "${OML_HOME}/env/.env.template"; do
    if [ -f "$f" ]; then
      has_files=true
      break
    fi
  done

  if [ "$has_files" = false ]; then
    return 0
  fi

  mkdir -p "$backup_dir"

  # Copy each config file if it exists
  for f in "${config_dir}/opencode.json" "${config_dir}/oh-my-opencode.jsonc" "${OML_HOME}/env/.env.template"; do
    if [ -f "$f" ]; then
      cp "$f" "$backup_dir/"
    fi
  done

  oml_info "Backup created: ${backup_dir}"

  # Prune old backups — keep only the most recent OML_MAX_BACKUPS
  _oml_prune_backups "$backups_dir"
}

# Keep only the most recent N backups, removing older ones
# Usage: _oml_prune_backups <backups-dir>
_oml_prune_backups() {
  local backups_dir="$1"

  # List backup dirs sorted by name (timestamp), newest last
  local backup_dirs=()
  while IFS= read -r d; do
    backup_dirs+=("$d")
  done < <(find "$backups_dir" -mindepth 1 -maxdepth 1 -type d | sort)

  local total="${#backup_dirs[@]}"
  if [ "$total" -le "$OML_MAX_BACKUPS" ]; then
    return 0
  fi

  local to_remove=$(( total - OML_MAX_BACKUPS ))
  local i=0
  for dir in "${backup_dirs[@]}"; do
    if [ "$i" -ge "$to_remove" ]; then break; fi
    rm -rf "$dir"
    oml_info "Removed old backup: $(basename "$dir")"
    i=$((i + 1))
  done
}

# List available backups with timestamps and sizes
# Usage: oml_backup_list
oml_backup_list() {
  local backups_dir="${OML_HOME}/backups"

  if [ ! -d "$backups_dir" ]; then
    oml_info "No backups found."
    return 0
  fi

  local count=0
  while IFS= read -r dir; do
    local ts
    ts="$(basename "$dir")"
    local size
    size="$(du -sh "$dir" 2>/dev/null | cut -f1)"
    printf "  %s  (%s)\n" "$ts" "${size:-unknown}"
    count=$((count + 1))
  done < <(find "$backups_dir" -mindepth 1 -maxdepth 1 -type d | sort -r)

  if [ "$count" -eq 0 ]; then
    oml_info "No backups found."
  else
    echo ""
    oml_info "$count backup(s) available. Use 'oml rollback [timestamp]' to restore."
  fi
}

# Restore config from a backup
# Usage: oml_rollback [timestamp]
# If no timestamp given, restores the most recent backup.
oml_rollback() {
  local target_ts="${1:-}"
  local backups_dir="${OML_HOME}/backups"
  local config_dir="${OML_HOME}/config"
  local env_dir="${OML_HOME}/env"

  if [ ! -d "$backups_dir" ]; then
    oml_error "No backups directory found at $backups_dir"
    return 1
  fi

  local backup_dir
  if [ -n "$target_ts" ]; then
    backup_dir="${backups_dir}/${target_ts}"
    if [ ! -d "$backup_dir" ]; then
      oml_error "Backup not found: $target_ts"
      oml_info "Available backups:"
      oml_backup_list
      return 1
    fi
  else
    # Use most recent backup
    backup_dir="$(find "$backups_dir" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
    if [ -z "$backup_dir" ]; then
      oml_error "No backups available to restore"
      return 1
    fi
  fi

  local ts
  ts="$(basename "$backup_dir")"
  oml_info "Restoring config from backup: $ts"

  mkdir -p "$config_dir" "$env_dir"

  # Restore each file from the backup
  local restored=0
  for f in "${backup_dir}"/*; do
    [ -f "$f" ] || continue
    local filename
    filename="$(basename "$f")"
    case "$filename" in
      opencode.json|oh-my-opencode.jsonc)
        cp "$f" "${config_dir}/${filename}"
        oml_info "Restored: ${config_dir}/${filename}"
        restored=$((restored + 1))
        ;;
      .env.template)
        cp "$f" "${env_dir}/${filename}"
        oml_info "Restored: ${env_dir}/${filename}"
        restored=$((restored + 1))
        ;;
    esac
  done

  if [ "$restored" -eq 0 ]; then
    oml_warn "No config files found in backup: $ts"
    return 1
  fi

  oml_success "Rolled back to backup: $ts ($restored file(s) restored)"
}
