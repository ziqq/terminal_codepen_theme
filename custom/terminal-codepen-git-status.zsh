# Exact D2 coloring for the Oh My Zsh `gss` shortcut.
# Native `git status --short` remains untouched.

function git_status_codepen() {
  local output line marker file_path escaped_marker escaped_path
  local -a lines

  output="$(command git -c color.status=false status --short "$@")" || return $?
  lines=("${(@f)output}")

  for line in "${lines[@]}"; do
    [[ -z "$line" ]] && continue

    marker="${line[1,2]}"
    file_path="${line[4,-1]}"
    escaped_marker="${marker//\%/%%}"
    escaped_path="${file_path//\%/%%}"

    case "$marker" in
      '??')
        print -P -- "%F{#809BBD}${escaped_marker}%f %F{#96B38A}${escaped_path}%f"
        ;;
      '!!')
        print -P -- "%F{#717790}${escaped_marker}%f %F{#717790}${escaped_path}%f"
        ;;
      *)
        print -P -- "%F{#FF5370}${escaped_marker}%f %F{#FF5370}${escaped_path}%f"
        ;;
    esac
  done
}

alias gss='git_status_codepen'
alias gscp='git_status_codepen'
