# CMS shell setup: the CMSSW environment and fixes for the el8 container.
#
# Installed by `cmsvm sync` as ~/.config/zsh/conf.d/cms.zsh and sourced by
# ~/.zshrc, whether that is guest/zshrc or a personal dotfiles zshrc that
# loads ~/.config/zsh/conf.d/*.zsh.

autoload -Uz add-zsh-hook

# Absolute path: EDITOR is inherited by the el8 container, which has no
# nvim on its default PATH. The ~/.local/bin nvim runs in both.
if [[ -x "$HOME/.local/bin/nvim" ]]; then
  export EDITOR="$HOME/.local/bin/nvim"
  export VISUAL="$EDITOR"
fi

if [[ -r /cvmfs/cms.cern.ch/cmsset_default.sh ]]; then
  source /cvmfs/cms.cern.ch/cmsset_default.sh
fi

# cmsset_default.sh puts /cvmfs/cms.cern.ch/common first, which would hide
# ~/bin/cmssw-el8 behind the CMS launcher of the same name. Move our
# directories back to the front (-U keeps only the first occurrence).
typeset -U path
path=("$HOME/bin" "$HOME/.local/bin" $path)

# ROOT's interpreter compiles dictionary headers when files are opened.
# The HLS ap_int headers used by the L1 track trigger formats trip clang's
# -Wformat (%llu with uint64_t) on every run. ROOT appends these flags to
# its defaults; this only silences printf/scanf format checks in cling.
export EXTRA_CLING_ARGS="-Wno-format"

# cmsenv sets LC_ALL=C. In the C locale zle counts the multibyte prompt
# character as several columns, so the command line gets garbled.
# Keep C for everything except character handling.
_cms_fix_locale() {
  if [[ "$LC_ALL" == C ]]; then
    unset LC_ALL
    export LC_CTYPE=en_US.UTF-8
  fi
}

add-zsh-hook precmd _cms_fix_locale
