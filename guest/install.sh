#!/usr/bin/env bash
#
# Install the repository-managed guest files. `cmsvm sync` copies the
# guest/ directory into the VM and runs this script there. Safe to re-run.

set -euo pipefail

SRC="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

STATE="$HOME/.local/share/cmssw-workspace"
ENV_PREFIX="$STATE/env"

MAMBA_VERSION="2.9.0"
MAMBA_SHA256="e705ffeed90ce0659eb546e4b1e1028c9eaf0bc9cc854867b19ac5ce0ba5852f"
MAMBA="$STATE/micromamba-$MAMBA_VERSION"

# Binaries from the tools environment that are linked into ~/.local/bin.
# Only these names are touched there.
TOOLS=(nvim rg fzf tree-sitter clangd clang-format)

mkdir -p "$STATE" "$HOME/.local/bin" "$HOME/bin" "$HOME/.config"


echo "==> micromamba $MAMBA_VERSION"

if [[ ! -x "$MAMBA" ]]; then
  tmp="$(mktemp -d)"

  curl -fsSL \
    -o "$tmp/micromamba.tar.bz2" \
    "https://micro.mamba.pm/api/micromamba/linux-aarch64/$MAMBA_VERSION"

  echo "$MAMBA_SHA256  $tmp/micromamba.tar.bz2" | sha256sum --check --quiet

  tar -xjf "$tmp/micromamba.tar.bz2" -C "$tmp" bin/micromamba
  mv "$tmp/bin/micromamba" "$MAMBA"
  rm -rf "$tmp"
fi


echo "==> Tools environment"

# Rebuild only when the pinned package list changes.
if cmp -s "$SRC/tools.txt" "$ENV_PREFIX/tools.txt"; then
  echo "    up to date"
else
  MAMBA_ROOT_PREFIX="$STATE/mamba" "$MAMBA" create \
    --yes \
    --quiet \
    --prefix "$ENV_PREFIX" \
    --override-channels \
    --channel conda-forge \
    --file "$SRC/tools.txt"

  cp "$SRC/tools.txt" "$ENV_PREFIX/tools.txt"

  # Drop the downloaded package cache.
  MAMBA_ROOT_PREFIX="$STATE/mamba" "$MAMBA" clean --all --yes --quiet
fi

for tool in "${TOOLS[@]}"; do
  link="$HOME/.local/bin/$tool"

  if [[ -e "$link" && ! -L "$link" ]]; then
    echo "ERROR: $link exists and is not a symlink; not replacing it" >&2
    exit 1
  fi

  ln -sfn "$ENV_PREFIX/bin/$tool" "$link"
done


echo "==> Shell and helpers"

if [[ -f "$HOME/.zshrc" ]] && ! cmp -s "$SRC/zshrc" "$HOME/.zshrc"; then
  backup="$HOME/.zshrc.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$HOME/.zshrc" "$backup"
  echo "    previous .zshrc saved as $backup"
fi

install -m 644 "$SRC/zshrc" "$HOME/.zshrc"
install -m 755 "$SRC/bin/cmssw-el8" "$HOME/bin/cmssw-el8"


echo "==> Neovim configuration and plugins"

# The repository is the source of truth for ~/.config/nvim.
rsync -a --delete "$SRC/nvim/" "$HOME/.config/nvim/"

nvim="$HOME/.local/bin/nvim"

if [[ -f "$HOME/.config/nvim/lazy-lock.json" ]]; then
  "$nvim" --headless "+Lazy! restore" +qa
else
  "$nvim" --headless "+Lazy! install" +qa
fi

# Parsers are compiled locally with the system gcc.
"$nvim" --headless \
  "+lua require('nvim-treesitter').install(vim.g.ts_parsers):wait(600000)" \
  +qa

echo
echo "Guest tools and configuration installed."
