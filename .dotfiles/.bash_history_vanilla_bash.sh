#!/usr/bin/env bash
# shellcheck disable=SC2016
BASH_HIST_AWK_CMD='{printf "%s\t%s\t%s\n", substr($3,2), substr($1,1,19), $2}'

function __bh_pull_matches() {
  local ignore_commands
  ignore_commands="$1" && shift
  hist_grep "$@" | tail -n +2 | command grep -Ev '\s('"$ignore_commands"')(\s|$)' | sed '1!G;h;$!d' | head -"${BASH_HIST_SELECT_LIMIT}" | awk -F $'\t' "$BASH_HIST_AWK_CMD" | csvlook --tabs --no-header-row | tail -n +3
}
function __bh_ask_user_to_select_cmd() {
  local found_cmd exit_val
  found_cmd="$(__bh_pull_matches "$@" | fzf --no-sort --layout=reverse --multi --header='Please select the command from the list below.')"
  exit_val="$?"
  if test "$exit_val" -ne 0; then
    return "$exit_val"
  fi
  if test -z "$found_cmd"; then
    echo "Nothing selected, exiting..."
    return 1
  fi
  echo "$found_cmd"
}

function _bh_vanilla_hist() {
  local use_pager=true
  local bh_pager="${BASH_HIST_PAGER:-$PAGER}"
  if test "${1-}" = '--no-pager'; then
    use_pager=false
    shift
  elif test "${1-}" = '--pager'; then
    use_pager=true
    shift
  elif test -z "${bh_pager}"; then
    use_pager=false
  elif ! test -t 1; then
    use_pager=false
  fi

  local sort_reverse_cmd
  if command -v tac >/dev/null 2>&1; then
    sort_reverse_cmd='tac'
  else
    sort_reverse_cmd='tail -r'
  fi

  local size="${1-}"
  if test -z "$size"; then
    if test "$use_pager" = 'true'; then
      size='500'
    else
      size='50'
    fi
  fi
  local remaining_size="$size"
  local file_pos=1
  local curr_size=0
  local out add_out all_logs
  all_logs="$(ls -t "$BASH_HIST_LOGS/bash-history"*.log)"
  while ((size > curr_size)); do
    add_out="$(tail <"$(echo "$all_logs" | head "-$file_pos" | tail -1)" "-$remaining_size" | $sort_reverse_cmd)"
    add_size="$(echo "$add_out" | wc -l | tr -d '\011\012\015')"
    file_pos="$((file_pos + 1))"
    curr_size="$((curr_size + add_size))"
    remaining_size="$((size - curr_size))"
    test -z "$out" && out="$add_out" || out="${out}"$'\n'"${add_out}"
  done
  if test "$use_pager" = 'true'; then
    {
      echo 'Command'$'\t''Time'$'\t''PWD'
      echo "$out" | awk -F $'\t' "$BASH_HIST_AWK_CMD"
    } | eval "${bh_pager}"
  else
    {
      echo 'Time'$'\t''PWD'$'\t''Command'
      echo "$out"
    }
  fi
}
function _bh_vanilla_hist_grep() {
  local use_pager=true
  local bh_pager="${BASH_HIST_PAGER:-$PAGER}"
  if test "${1-}" = '--no-pager'; then
    use_pager=false
    shift
  elif test "${1-}" = '--pager'; then
    use_pager=true
    shift
  elif test -z "${bh_pager}"; then
    use_pager=false
  elif ! test -t 1; then
    use_pager=false
  fi
  local grep_args=("$@")
  if test "${1-}" = '--use-case'; then
    shift
    grep_args=("$@")
  elif ! [[ ${*: -1} =~ [A-Z] ]]; then
    grep_args+=("-i")
  fi

  local old_nullglob all_log_files_temp all_log_files
  old_nullglob="$(shopt -p nullglob)"
  shopt -s nullglob
  all_log_files_temp=("$BASH_HIST_LOGS/bash-history"*.log)
  mapfile -td '' all_log_files < <(printf '%s\0' "${all_log_files_temp[@]}" | sort -rz)
  eval "$old_nullglob"

  if test "$use_pager" = 'true'; then
    {
      echo 'Command'$'\t''Time'$'\t''PWD'
      command grep --color=auto --no-filename -E "${grep_args[@]}" "${all_log_files[@]}" | sort -r | awk -F $'\t' "$BASH_HIST_AWK_CMD"
    } | eval "${bh_pager}"
  else
    {
      echo 'Time'$'\t''PWD'$'\t''Command'
      command grep --color=auto --no-filename -E "${grep_args[@]}" "${all_log_files[@]}" | sort
    }
  fi
}
function _bh_vanilla_hist_grep_copy() {
  local exec_cmd_full exec_cmd exit_val
  exec_cmd_full="$(__bh_ask_user_to_select_cmd 'hgc|hist_grep_copy' "$@")"
  exit_val="$?"
  if test "$exit_val" -ne 0; then
    return "$exit_val"
  fi
  echo "${exec_cmd_full}"
  exec_cmd="$(bash_history_extract_command "${exec_cmd_full}")"
  echo -n "$exec_cmd" | pbcopy
  exit_val=$?
  if [ $exit_val -eq 0 ]; then
    echo "Copied: $exec_cmd"
  fi
  return $exit_val
}
function _bh_vanilla_hist_grep_exec() {
  local exec_cmd_full exec_cmd exit_val
  exec_cmd_full="$(__bh_ask_user_to_select_cmd 'hge|hist_grep_exec' "$@")"
  exit_val="$?"
  if test "$exit_val" -ne 0; then
    return "$exit_val"
  fi
  echo "${exec_cmd_full}"
  exec_cmd="$(bash_history_extract_command "${exec_cmd_full}")"
  history -s "$exec_cmd"
  echo "Running: $exec_cmd"$'\n''---------------------------------'
  eval "$exec_cmd"
  return $?
}
function _bh_vanilla_hist_grep_pwd() {
  local search
  search="$(pwd)\s.*${1}" && shift
  hist_grep "${search}" "$@"
}
function _bh_vanilla_hist_grep_unique() {
  hist_grep "$@" | cut -f3 | awk '!x[$0]++'
}
