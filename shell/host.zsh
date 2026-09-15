# Host-side integration for cmssw-workspace.

typeset -U path PATH

# Resolve repository root from this file:
#   <repo>/shell/host.zsh
typeset _cmssw_workspace_root="${${(%):-%N}:A:h:h}"

path=(
  "$_cmssw_workspace_root/bin"
  $path
)

export CMSSW_LIMA_INSTANCE="${CMSSW_LIMA_INSTANCE:-cmssw}"

alias cmssw='cmsvm shell'
alias cmssw-start='cmsvm start'
alias cmssw-stop='cmsvm stop'
alias cmssw-status='cmsvm status'
alias cmssw-ssh='cmsvm ssh'

if (( $+commands[limactl] )); then
  source <(limactl completion zsh)
fi

unset _cmssw_workspace_root
