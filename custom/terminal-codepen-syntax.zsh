# CodePen syntax colors for commands typed into Zsh.
# The Terminal.app profile controls the window and ANSI output; this file
# controls the command line before Zsh executes it.

typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]='fg=#ffffff'
ZSH_HIGHLIGHT_STYLES[command]='fg=#ddca7e'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#ddca7e'
ZSH_HIGHLIGHT_STYLES[function]='fg=#9a8297'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#809bbd'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#ddca7e'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#ddca7e'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#809bbd'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#809bbd'
ZSH_HIGHLIGHT_STYLES[path]='fg=#96b38a'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#9a8297'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#9a8297'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#96b38a'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#96b38a'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#96b38a'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#96b38a'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#cccccc'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#717790'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f07178'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#809bbd'

syntax_highlighting_file="${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
if [[ -r "$syntax_highlighting_file" ]]; then
  source "$syntax_highlighting_file"
fi
