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
        ├── zsh / tmux / Neovim / ripgrep / fzf / clangd
        ├── cmssw-el8: CMS el8 container (apptainer) for el8-only releases
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
│   ├── smoke-test.env
│   └── smoke-test-el8.env
├── docs/
│   └── el8.md
├── guest/
│   ├── bin/cmssw-el8
│   ├── nvim/
│   │   ├── init.lua
│   │   └── lazy-lock.json
│   ├── install.sh
│   ├── tools.txt
│   ├── zsh/cms.zsh
│   └── zshrc
├── lima/
│   └── cmssw.yaml
├── shell/
│   └── host.zsh
└── README.md
```

`guest/` holds what `cmsvm sync` installs into the VM: the pinned tools, `~/.zshrc`, the CMS shell setup, the Neovim configuration and the `cmssw-el8` helper.

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

This creates and provisions a native AArch64 AlmaLinux VM with CVMFS, CMS prerequisites, development tools, SSH integration, zsh, and terminal support. It then runs `cmsvm sync` to install the files from `guest/`.

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
- Neovim, ripgrep, fzf and clangd from `cmsvm sync`
- Ghostty terminfo when applicable
- CVMFS
- CMS repositories
- SCRAM
- the el8 container, and Neovim inside it
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

## Guest tools and configuration

The guest's shell and editor setup lives in `guest/` and is installed by:

```bash
cmsvm sync
```

It installs:

- the conda-forge packages pinned in `guest/tools.txt` (Neovim, ripgrep, fzf, fd, tree-sitter, clangd, lazygit, shellcheck, bat, starship) under `~/.local/share/cmssw-workspace`, linked into `~/.local/bin`;
- `guest/zsh/cms.zsh` as `~/.config/zsh/conf.d/cms.zsh`: the CMS environment (`cmsset_default.sh`), the el8 container fixes and the ROOT/cling flags;
- `guest/zshrc` as `~/.zshrc`, keeping a dated backup if the old one differed; it sources `~/.config/zsh/conf.d/*.zsh`;
- `guest/nvim/` as `~/.config/nvim`, then the plugins pinned in `lazy-lock.json` and the Tree-sitter parsers;
- `guest/bin/cmssw-el8` as `~/bin/cmssw-el8`.

`cmsvm sync` also copies the host's Git identity into the VM again, and brings the VM's provisioning scripts up to date with `lima/cmssw.yaml`. Lima runs them at every boot from the copy of the template made when the VM was created, so a VM created from an older template would keep running old scripts. When they differ, a running VM is restarted.

conda-forge builds against an old glibc, so the same binaries also run in the el8 container. `cmsvm sync` is safe to re-run and only rebuilds the tools when `tools.txt` changes.

The repository is the source of truth: `cmsvm sync` overwrites `~/.zshrc` and `~/.config/nvim`. Make changes in `guest/` and sync them.

### Personal dotfiles

To use your own shell and editor setup in the VM instead of `guest/zshrc` and `guest/nvim`, keep it in a dotfiles repository on the Mac with an executable `install.sh` at the top. When `~/dotfiles/install.sh` exists (or the directory named by `CMSVM_DOTFILES`), `cmsvm sync`:

1. installs the tools and the CMS shell setup from `guest/` as usual, but leaves `~/.zshrc` and `~/.config/nvim` alone;
2. copies the dotfiles to `~/dotfiles` in the VM (without `.git`) and runs `~/dotfiles/install.sh` there, with the guest tools on `PATH`.

The dotfiles' `.zshrc` should source `~/.config/zsh/conf.d/*.zsh` to pick up the CMS setup. The copy in the VM is overwritten on every sync, so edit the dotfiles on the Mac. `CMSVM_DOTFILES=none cmsvm sync` goes back to `guest/`'s files. To update the plugins, run `:Lazy update` in the VM, then copy the new lock file back into the repository:

```bash
scp lima-cmssw:.config/nvim/lazy-lock.json guest/nvim/
```

## el8 releases

Some releases, such as `CMSSW_20_0_0_patch1`, exist for `el8_aarch64_gcc13` but not for `el9_aarch64`. They run in the CMS el8 container from CVMFS, inside the VM:

```bash
cmssw-el8                       # interactive zsh, prompt starts with [el8]
cmssw-el8 cmsRun config.py      # one command
```

`cmssw-el8` wraps `/cvmfs/cms.cern.ch/common/cmssw-el8`. It puts apptainer from CVMFS on `PATH`, sets `SCRAM_ARCH=el8_aarch64_gcc13` unless another el8 architecture is set, and starts zsh with the usual `~/.zshrc`, plugins, Neovim and fzf. The container shares the VM's kernel, `/home`, `/cvmfs` and `/data`, and runs at native speed.

`cmssw-bootstrap --arch el8_…` runs in the container automatically. An el8 VM is not an option: the el8 aarch64 kernel uses 64 KB pages, which Apple Silicon does not support. See `docs/el8.md`.

## CMSSW bootstrap

Create a clean CMSSW development area explicitly:

```bash
cmssw-bootstrap \
  --arch el9_aarch64_gcc14 \
  --release CMSSW_20_1_0_pre3
```

`--release` takes an exact release or IB name, such as `CMSSW_20_1_0_pre3` or `CMSSW_20_1_X_2026-10-04-2300`, or an IB series such as `CMSSW_20_1_X`. A series resolves to its newest IB available for the architecture. IBs are only kept on CVMFS for a few weeks, so dated IB names stop working after that.

The bootstrap:

1. verifies the CMS environment;
2. verifies the requested SCRAM architecture;
3. resolves an IB series to its newest IB and verifies the release exists;
4. verifies the CMS Git identity;
5. creates the release with `cmsrel`;
6. activates it with `cmsenv`;
7. initializes the CMSSW Git development area with `git cms-init`.

Existing release areas are never silently reused or modified.

The area is created in `~/work` unless `--workdir` names another guest directory. Quote a `~` so that the guest expands it: `--workdir '~/scratch/test'`.

The architecture's OS must match the VM (el9), except for el8 architectures, which run in the el8 container:

```bash
cmssw-bootstrap \
  --arch el8_aarch64_gcc13 \
  --release CMSSW_20_0_0_patch1
```

## Reproducibility smoke test

The repository contains a pinned known-good smoke-test configuration:

```text
config/smoke-test.env
```

Run:

```bash
cmssw-bootstrap --smoke-test
cmssw-bootstrap --smoke-test el8
```

Each run creates its area in a new directory under `~/scratch/smoke-test-<date>-<time>`, so existing areas in `~/work` are never touched. Delete the old directories when they are no longer needed. The el8 test uses `config/smoke-test-el8.env` (`CMSSW_20_0_0_patch1` with `el8_aarch64_gcc13`, in the el8 container).

The current smoke test uses:

```text
SCRAM_ARCH=el9_aarch64_gcc14
CMSSW_RELEASE=CMSSW_20_1_0_pre3
CMSSW_SMOKE_PACKAGE=DataFormats/SiStripCluster
```

It is pinned to a pre-release rather than an IB because pre-releases stay on CVMFS, while IBs are removed after a few weeks. It creates a fresh release area, initializes the CMS Git checkout, checks out the package, and performs a native ARM64 C++ build.

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
cmssw-bootstrap --smoke-test el8
```

If all five commands succeed, the complete local CMSSW environment has been recreated from repository configuration.

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

### Neovim

`guest/nvim/init.lua` is a small configuration built on lazy.nvim:

- Catppuccin (mocha) theme and lualine status line;
- Tree-sitter highlighting and indentation;
- fzf-lua: `<Space>ff` files, `<Space>fg` grep, `<Space>fw` word under cursor, `<Space>fb` buffers, `<Space>fs` symbols, `<Space>fd` diagnostics;
- gitsigns: `]c`/`[c` next/previous hunk, `<Space>hp` preview, `<Space>hr` reset, `<Space>hb` blame;
- clangd with Neovim's built-in completion, and `<Space>cf` to format; Neovim's default LSP keys apply (`K`, `grr`, `grn`, `gra`, `gri`);
- which-key, which lists the mappings after `<Space>`;
- `<Space>y` copies to the macOS clipboard through OSC 52.

For clangd in a CMSSW area, generate the compilation database after building:

```bash
scram b llvm-ccdb
```

It writes `compile_commands.json` to `$CMSSW_BASE`, and clangd finds it from any file below. The database names the compiler as plain `clang++`, so start nvim from a shell where `cmsenv` has been run; clangd then asks the CMS compiler for its system headers.

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