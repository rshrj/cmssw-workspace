-- Neovim configuration for the CMSSW VM and the el8 container.
--
-- Managed by cmssw-workspace (guest/nvim); `cmsvm sync` overwrites
-- ~/.config/nvim. Plugins are pinned by lazy-lock.json.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- clangd, rg and fzf live in ~/.local/bin, which is not on PATH when nvim
-- is started from the plain CMS el8 container launcher.
local local_bin = vim.fn.expand("~/.local/bin")
if not vim.env.PATH:find(local_bin, 1, true) then
  vim.env.PATH = local_bin .. ":" .. vim.env.PATH
end

-- ------------------------------------------------------------------
-- Options
-- ------------------------------------------------------------------

vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes"
vim.o.cursorline = true
vim.o.scrolloff = 5
vim.o.mouse = "a"

vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2

vim.o.splitright = true
vim.o.splitbelow = true
vim.o.undofile = true
vim.o.updatetime = 250
vim.o.timeoutlen = 400

vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.o.completeopt = "menuone,noselect,popup,fuzzy"

-- The VM has no clipboard tool; OSC 52 copies through the terminal to
-- the macOS clipboard. Only copying is mapped: OSC 52 paste requests are
-- refused or prompted by most terminals.
vim.g.clipboard = "osc52"
vim.keymap.set({ "n", "x" }, "<leader>y", '"+y', { desc = "Copy to macOS clipboard" })

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>")

-- Briefly highlight yanked text.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank()
  end,
})

-- ------------------------------------------------------------------
-- Plugins (lazy.nvim)
-- ------------------------------------------------------------------

-- Parsers installed by `cmsvm sync` (guest/install.sh).
vim.g.ts_parsers = {
  "bash", "c", "cmake", "cpp", "diff", "git_rebase", "gitcommit",
  "json", "lua", "make", "markdown", "markdown_inline", "python",
  "query", "toml", "vim", "vimdoc", "xml", "yaml",
}

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({ flavour = "mocha" })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          -- Fails quietly for filetypes without an installed parser.
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "FzfLua",
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "Word under cursor" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Help" },
      { "<leader>fr", "<cmd>FzfLua resume<cr>", desc = "Resume last search" },
      { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Symbols" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_document<cr>", desc = "Diagnostics" },
    },
    opts = {},
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
        end
        map("]c", function() gs.nav_hunk("next") end, "Next hunk")
        map("[c", function() gs.nav_hunk("prev") end, "Previous hunk")
        map("<leader>hp", gs.preview_hunk, "Preview hunk")
        map("<leader>hr", gs.reset_hunk, "Reset hunk")
        map("<leader>hb", gs.blame_line, "Blame line")
      end,
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>h", group = "git hunk" },
        { "<leader>c", group = "code" },
      },
    },
  },
}, {
  checker = { enabled = false },
  change_detection = { enabled = false },
  rocks = { enabled = false },
})

-- ------------------------------------------------------------------
-- C++: clangd with built-in completion
-- ------------------------------------------------------------------

-- In a CMSSW area, `scram b llvm-ccdb` writes compile_commands.json to
-- $CMSSW_BASE; clangd finds it from any file below. Its compiler is a
-- plain `clang++`, found through the PATH that cmsenv sets, so start nvim
-- after cmsenv. --query-driver lets clangd ask the CMS compilers on CVMFS
-- for their system headers, and the system compilers for other projects.
vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--header-insertion=never",
    "--query-driver=/cvmfs/cms.cern.ch/**/bin/*g++*,/cvmfs/cms.cern.ch/**/bin/clang++,/usr/bin/cc,/usr/bin/c++,/usr/bin/gcc*,/usr/bin/g++*",
  },
  filetypes = { "c", "cpp" },
  root_markers = { "compile_commands.json", ".git" },
})
vim.lsp.enable("clangd")

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
    vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { buffer = args.buf, desc = "Format" })
  end,
})

vim.diagnostic.config({ virtual_text = true })
