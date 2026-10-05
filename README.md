# cmssw-workspace

A reproducible local CMSSW development environment for Apple Silicon Macs.

The workspace runs CMSSW inside a native ARM64 AlmaLinux VM managed by Lima, while keeping the macOS host clean. It provides CVMFS, CMS tooling, Git/GitHub integration, an ergonomic zsh environment, Ghostty support, and reproducible CMSSW release bootstrapping.

## Architecture

```text
Apple Silicon macOS
        │
        │ Lima / Apple Virtualization.framework
        ▼
AlmaLinux 9 ARM64
        │
        ├── Rosetta x86_64 translation
        ├── CVMFS
        │   ├── cms.cern.ch
        │   ├── cms-ib.cern.ch
        │   ├── cms-ci.cern.ch
        │   └── grid.cern.ch
        │
        ├── CMS SCRAM environment
        ├── Git + cms-git-tools
        ├── zsh / tmux / Neovim / ripgrep / fzf
        └── ~/work
              └── CMSSW development areas
```

CMSSW source and build trees live on the VM's native Linux filesystem rather than a macOS shared mount.

## Repository layout

```text
.
├── bin/
│   ├── cmsvm
│   └── cmssw-bootstrap
├── config/
│   └── smoke-test.env
├── lima/
│   └── cmssw.yaml
├── shell/
│   └── host.zsh
└── README.md
```

## Requirements

- Apple Silicon Mac
- Homebrew
- Lima 2.2.0 or compatible
- OpenSSH
- Git
- Rosetta installed on macOS where required

Install Lima:

```bash
brew install lima
```

Configure the Git identity required by CMS:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global user.github "your-github-username"
```

## Install

Clone the repository:

```bash
git clone git@github.com:<username>/cmssw-workspace.git
cd cmssw-workspace
```

Add the workspace helpers to the host shell:

```bash
printf '\nsource "%s/shell/host.zsh"\n' "$PWD" >> ~/.zshrc
exec zsh
```

Validate the Lima configuration:

```bash
cmsvm validate
```

Create the VM:

```bash
cmsvm create
```

This creates and provisions a native AArch64 AlmaLinux VM with CVMFS, CMS prerequisites, development tools, SSH integration, zsh, and terminal support.

## Verify the environment

Run:

```bash
cmsvm doctor
```

A healthy environment verifies:

- Lima configuration
- AArch64 guest architecture
- AlmaLinux
- zsh login shell
- SSH integration
- Ghostty terminfo when applicable
- CVMFS
- CMS repositories
- SCRAM
- Git identity

## Enter the VM

```bash
cmssw
```

or:

```bash
cmsvm shell
```

The VM is automatically started if necessary.

The Linux development workspace is:

```text
~/work
```

## VM lifecycle

```bash
cmsvm status
cmsvm start
cmsvm shell
cmsvm stop
cmsvm delete
```

The VM is disposable. Permanent configuration belongs in this repository rather than in manual changes to the Lima instance.

## Host directories

The VM does not mount anything from macOS by default. To share a host directory, such as large input ROOT files that should survive `cmsvm delete`, mount it explicitly:

```bash
cmsvm mount ~/path/to/cms-data /data/cms   # read-only
cmsvm mount ~/path/to/outputs --rw         # writable, at /mnt/outputs
cmsvm mounts
cmsvm unmount /data/cms
```

Mounts are read-only unless `--rw` is given, and the guest directory defaults to `/mnt/<name>`. Changing mounts restarts a running VM. Mounts are saved in `config/mounts.local`, which is not tracked by Git, and `cmsvm create` re-applies them to a new VM.

Keep CMSSW source and build trees on the VM filesystem, and write job output there (for example `~/work` or `~/scratch`) unless a mount is writable on purpose.

## CMSSW bootstrap

Create a clean CMSSW development area explicitly:

```bash
cmssw-bootstrap \
  --arch el9_aarch64_gcc14 \
  --release CMSSW_20_1_X_2026-09-13-2300
```

The bootstrap:

1. verifies the CMS environment;
2. verifies the requested SCRAM architecture;
3. verifies the requested CMSSW release exists;
4. verifies the CMS Git identity;
5. creates the release with `cmsrel`;
6. activates it with `cmsenv`;
7. initializes the CMSSW Git development area with `git cms-init`.

Existing release areas are never silently reused or modified.

## Reproducibility smoke test

The repository contains a pinned known-good smoke-test configuration:

```text
config/smoke-test.env
```

Run:

```bash
cmssw-bootstrap --smoke-test
```

The current smoke test uses:

```text
SCRAM_ARCH=el9_aarch64_gcc14
CMSSW_RELEASE=CMSSW_20_1_X_2026-09-13-2300
CMSSW_SMOKE_PACKAGE=DataFormats/SiStripCluster
```

It creates a fresh release area, initializes the CMS Git checkout, checks out the package, and performs a native ARM64 C++ build.

This validates the full chain:

```text
Apple Silicon
→ AlmaLinux ARM64
→ CVMFS
→ CMSSW 20_1_X gcc14
→ CMSSW Git development area
→ native C++ compilation
```

## Clean-room test

To verify reproducibility from a fresh VM:

```bash
cmsvm delete
cmsvm create
cmsvm doctor
cmssw-bootstrap --smoke-test
```

If all four commands succeed, the complete local CMSSW environment has been recreated from repository configuration.

## SSH

The workspace configures Lima's generated SSH host:

```bash
ssh lima-cmssw
```

This also makes the VM usable through:

- VS Code Remote SSH
- `scp`
- `rsync`
- ordinary OpenSSH tooling

The macOS SSH agent is forwarded into the VM so private GitHub keys do not need to be copied into Linux.

## Editors and terminals

The guest includes:

- zsh
- Neovim
- tmux
- ripgrep
- fzf

VS Code can connect to:

```text
lima-cmssw
```

using Remote SSH.

Ghostty's `xterm-ghostty` terminfo definition is installed automatically during VM creation when needed.

## Design principles

- Keep macOS clean.
- Run CMSSW natively on Linux ARM64 where possible.
- Keep CMSSW builds on the VM's Linux filesystem.
- Pin reproducibility tests rather than selecting arbitrary "latest" releases.
- Keep developer identity outside committed configuration.
- Treat the VM as disposable.
- Keep project/PR-specific workflows separate from the generic machine bootstrap.