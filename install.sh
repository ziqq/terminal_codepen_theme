#!/usr/bin/env sh

set -eu

# Native MSYS2 executables started from PowerShell may inherit a Windows-only
# PATH. Unix-like systems already use these directories, so this is harmless.
PATH="/usr/bin:/bin:$PATH"
export PATH

THEME_DEFAULT='codepen'
THEME_COOL='codepen_cool'
SYNTAX_HIGHLIGHTING_REPO='https://github.com/zsh-users/zsh-syntax-highlighting.git'
MANAGED_START='# >>> terminal_codepen_theme >>>'
MANAGED_END='# <<< terminal_codepen_theme <<<'
SYNTAX_MANAGED_START='# >>> terminal_codepen_syntax >>>'
SYNTAX_MANAGED_END='# <<< terminal_codepen_syntax <<<'

variant='default'
install_git_helper='yes'
install_packages='yes'
set_default_shell='no'

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --variant default|cool    Theme to activate (default: default)
  --no-git-helper          Do not install D2-colored `gss`/`gscp`
  --skip-package-install   Fail instead of installing missing prerequisites
  --set-default-shell      Attempt to make Zsh the login shell
  -h, --help               Show this help
EOF
}

die() {
  printf 'terminal_codepen_theme: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'terminal_codepen_theme: %s\n' "$*"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --variant)
      [ "$#" -ge 2 ] || die '--variant requires default or cool'
      variant=$2
      shift 2
      ;;
    --variant=*)
      variant=${1#*=}
      shift
      ;;
    --no-git-helper)
      install_git_helper='no'
      shift
      ;;
    --skip-package-install)
      install_packages='no'
      shift
      ;;
    --set-default-shell)
      set_default_shell='yes'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case "$variant" in
  default) selected_theme=$THEME_DEFAULT ;;
  cool) selected_theme=$THEME_COOL ;;
  *) die "unsupported variant '$variant'; use default or cool" ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
os_name=$(uname -s 2>/dev/null || printf 'unknown')

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "administrator privileges are required to run: $*"
  fi
}

install_prerequisites() {
  missing=''
  command -v zsh >/dev/null 2>&1 || missing="$missing zsh"
  command -v git >/dev/null 2>&1 || missing="$missing git"
  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || missing="$missing curl"

  [ -n "$missing" ] || return 0
  [ "$install_packages" = 'yes' ] || die "missing prerequisites:$missing"

  info "installing missing prerequisites:$missing"

  if command -v apt-get >/dev/null 2>&1; then
    run_privileged apt-get update
    run_privileged apt-get install -y zsh git curl
  elif command -v dnf >/dev/null 2>&1; then
    run_privileged dnf install -y zsh git curl
  elif command -v yum >/dev/null 2>&1; then
    run_privileged yum install -y zsh git curl
  elif command -v zypper >/dev/null 2>&1; then
    run_privileged zypper --non-interactive install zsh git curl
  elif command -v apk >/dev/null 2>&1; then
    run_privileged apk add zsh git curl
  elif command -v pacman >/dev/null 2>&1; then
    run_privileged pacman -S --needed --noconfirm zsh git curl
  elif command -v brew >/dev/null 2>&1; then
    brew install zsh git curl
  else
    case "$os_name" in
      MINGW*|MSYS*|CYGWIN*)
        die 'no supported package manager found; run install.ps1 from Windows PowerShell'
        ;;
      Darwin)
        die 'install Zsh and Git first, or install Homebrew and rerun this script'
        ;;
      *)
        die 'no supported package manager found; install Zsh, Git, and curl, then rerun'
        ;;
    esac
  fi

  command -v zsh >/dev/null 2>&1 || die 'Zsh installation did not provide a zsh executable'
  command -v git >/dev/null 2>&1 || die 'Git installation did not provide a git executable'
}

install_oh_my_zsh() {
  zsh_dir=${ZSH:-"$HOME/.oh-my-zsh"}
  if [ -r "$zsh_dir/oh-my-zsh.sh" ]; then
    info "Oh My Zsh already installed at $zsh_dir"
    return 0
  fi

  [ ! -e "$zsh_dir" ] || die "$zsh_dir exists but is not a valid Oh My Zsh installation"
  info "installing Oh My Zsh into $zsh_dir"
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"
}

emit_theme_block() {
  cat <<EOF
$MANAGED_START
if [[ -r "\${ZSH_CUSTOM:-\$ZSH/custom}/themes/$selected_theme.zsh-theme" ]]; then
  ZSH_THEME="$selected_theme"
else
  ZSH_THEME="robbyrussell"
fi
$MANAGED_END
EOF
}

emit_syntax_block() {
  cat <<EOF
$SYNTAX_MANAGED_START
if [[ -r "\${ZSH_CUSTOM:-\$ZSH/custom}/terminal-codepen-syntax.zsh" ]]; then
  source "\${ZSH_CUSTOM:-\$ZSH/custom}/terminal-codepen-syntax.zsh"
fi
$SYNTAX_MANAGED_END
EOF
}

update_zshrc() {
  zshrc=${ZDOTDIR:-$HOME}/.zshrc
  zshrc_dir=$(dirname -- "$zshrc")
  mkdir -p "$zshrc_dir"

  if [ ! -e "$zshrc" ]; then
    cat >"$zshrc" <<EOF
export ZSH="$zsh_dir"

$(emit_theme_block)

plugins=(git)
source "\$ZSH/oh-my-zsh.sh"

$(emit_syntax_block)
EOF
    info "created $zshrc"
    return 0
  fi

  backup="$zshrc.pre-terminal-codepen-theme"
  [ -e "$backup" ] || cp "$zshrc" "$backup"

  temp_file=$(mktemp "${zshrc}.tmp.XXXXXX")
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" \
    -v syntax_start="$SYNTAX_MANAGED_START" -v syntax_end="$SYNTAX_MANAGED_END" \
    -v theme="$selected_theme" '
    function emit_block() {
      print start
      print "if [[ -r \"${ZSH_CUSTOM:-$ZSH/custom}/themes/" theme ".zsh-theme\" ]]; then"
      print "  ZSH_THEME=\"" theme "\""
      print "else"
      print "  ZSH_THEME=\"robbyrussell\""
      print "fi"
      print end
    }
    function emit_syntax_block() {
      print syntax_start
      print "if [[ -r \"${ZSH_CUSTOM:-$ZSH/custom}/terminal-codepen-syntax.zsh\" ]]; then"
      print "  source \"${ZSH_CUSTOM:-$ZSH/custom}/terminal-codepen-syntax.zsh\""
      print "fi"
      print syntax_end
    }
    $0 == start {
      if (!inserted) {
        emit_block()
        inserted = 1
      }
      managed = 1
      next
    }
    managed && $0 == end {
      managed = 0
      next
    }
    managed { next }
    $0 == syntax_start {
      if (!syntax_inserted) {
        emit_syntax_block()
        syntax_inserted = 1
      }
      syntax_managed = 1
      next
    }
    syntax_managed && $0 == syntax_end {
      syntax_managed = 0
      next
    }
    syntax_managed { next }
    !inserted && $0 ~ /^[[:space:]]*ZSH_THEME[[:space:]]*=/ {
      emit_block()
      inserted = 1
      next
    }
    !inserted && $0 ~ /^[[:space:]]*source[[:space:]].*oh-my-zsh\.sh/ {
      emit_block()
      print
      print ""
      emit_syntax_block()
      syntax_inserted = 1
      inserted = 1
      next
    }
    { print }
    END {
      if (!inserted) {
        print ""
        emit_block()
      }
      if (!syntax_inserted) {
        print ""
        emit_syntax_block()
      }
    }
  ' "$zshrc" >"$temp_file"
  mv "$temp_file" "$zshrc"
  info "updated $zshrc (backup: $backup)"
}

install_theme_files() {
  zsh_custom=${ZSH_CUSTOM:-"$zsh_dir/custom"}
  themes_dir="$zsh_custom/themes"
  mkdir -p "$themes_dir"
  cp "$script_dir/themes/$THEME_DEFAULT.zsh-theme" "$themes_dir/$THEME_DEFAULT.zsh-theme"
  cp "$script_dir/themes/$THEME_COOL.zsh-theme" "$themes_dir/$THEME_COOL.zsh-theme"

  if [ "$install_git_helper" = 'yes' ]; then
    cp "$script_dir/custom/terminal-codepen-git-status.zsh" "$zsh_custom/terminal-codepen-git-status.zsh"
  fi
  cp "$script_dir/custom/terminal-codepen-syntax.zsh" "$zsh_custom/terminal-codepen-syntax.zsh"
}

install_syntax_highlighting() {
  plugin_dir="$zsh_custom/plugins/zsh-syntax-highlighting"
  plugin_file="$plugin_dir/zsh-syntax-highlighting.zsh"
  if [ -r "$plugin_file" ]; then
    info "zsh-syntax-highlighting already installed at $plugin_dir"
    return 0
  fi

  [ ! -e "$plugin_dir" ] || die "$plugin_dir exists but is not a valid zsh-syntax-highlighting installation"
  mkdir -p "$(dirname -- "$plugin_dir")"
  info "installing zsh-syntax-highlighting into $plugin_dir"
  git clone --depth=1 "$SYNTAX_HIGHLIGHTING_REPO" "$plugin_dir"
}

maybe_set_default_shell() {
  [ "$set_default_shell" = 'yes' ] || return 0
  zsh_path=$(command -v zsh)
  current_shell=${SHELL:-}
  [ "$current_shell" = "$zsh_path" ] && return 0
  command -v chsh >/dev/null 2>&1 || die 'chsh is unavailable; cannot set the default shell'
  chsh -s "$zsh_path"
}

verify_installation() {
  command zsh -n "$zsh_custom/themes/$selected_theme.zsh-theme"
  if [ "$install_git_helper" = 'yes' ]; then
    command zsh -n "$zsh_custom/terminal-codepen-git-status.zsh"
  fi
  command zsh -n "$zsh_custom/terminal-codepen-syntax.zsh"
  command zsh -n "$zsh_custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
}

install_prerequisites
install_oh_my_zsh
install_theme_files
install_syntax_highlighting
update_zshrc
maybe_set_default_shell
verify_installation

info "installed '$selected_theme' with runtime fallback to robbyrussell"
info 'restart Zsh or run: exec zsh'
