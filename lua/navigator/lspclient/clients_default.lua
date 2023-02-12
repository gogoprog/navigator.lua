local M = {}
local vfn = vim.fn
M.defaults = function()
  local has_lsp, lspconfig = pcall(require, 'lspconfig')
  local highlight = require('navigator.lspclient.highlight')
  if not has_lsp then
    return {
      setup = function()
        vim.notify('loading lsp config failed LSP may not working correctly', vim.lsp.log_levels.WARN)
      end,
    }
  end
  local util = lspconfig.util
  local on_attach = require('navigator.lspclient.attach').on_attach


  local setups = {
    clojure_lsp = {
      root_dir = function(fname)
        return util.root_pattern('deps.edn', 'build.boot', 'project.clj', 'shadow-cljs.edn', 'bb.edn', '.git')(fname)
          or util.path.dirname(fname)
      end,
      on_attach = on_attach,
      filetypes = { 'clojure', 'edn' },
      message_level = vim.lsp.protocol.MessageType.error,
      cmd = { 'clojure-lsp' },
    },

    elixirls = {
      on_attach = on_attach,
      filetypes = { 'elixir', 'eelixir' },
      cmd = { 'elixir-ls' },
      message_level = vim.lsp.protocol.MessageType.error,
      settings = {
        elixirLS = {
          dialyzerEnabled = true,
          fetchDeps = false,
        },
      },
      root_dir = function(fname)
        return util.root_pattern('mix.exs', '.git')(fname) or util.path.dirname(fname)
      end,
    },

    gopls = {
      on_attach = on_attach,
      -- capabilities = cap,
      filetypes = { 'go', 'gomod', 'gohtmltmpl', 'gotexttmpl' },
      message_level = vim.lsp.protocol.MessageType.Error,
      cmd = {
        'gopls', -- share the gopls instance if there is one already
        '-remote=auto', --[[ debug options ]] --
        -- "-logfile=auto",
        -- "-debug=:0",
        '-remote.debug=:0',
        -- "-rpc.trace",
      },

      flags = { allow_incremental_sync = true, debounce_text_changes = 1000 },
      settings = {
        gopls = {
          -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
          -- flags = {allow_incremental_sync = true, debounce_text_changes = 500},
          -- not supported
          analyses = { unusedparams = true, unreachable = false },
          codelenses = {
            generate = true, -- show the `go generate` lens.
            gc_details = true, --  // Show a code lens toggling the display of gc's choices.
            test = true,
            tidy = true,
          },
          usePlaceholders = true,
          completeUnimported = true,
          staticcheck = true,
          matcher = 'fuzzy',
          diagnosticsDelay = '500ms',
          symbolMatcher = 'fuzzy',
          gofumpt = false, -- true, -- turn on for new repos, gofmpt is good but also create code turmoils
          buildFlags = { '-tags', 'integration' },
          -- buildFlags = {"-tags", "functional"}
        },
      },
      root_dir = function(fname)
        return util.root_pattern('go.mod', '.git')(fname) or util.path.dirname(fname)
      end,
    },
    clangd = {
      flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
      cmd = {
        'clangd',
        '--background-index',
        '--suggest-missing-includes',
        '--clang-tidy',
        '--header-insertion=iwyu',
        '--enable-config',
        '--offset-encoding=utf-16',
        '--clang-tidy-checks=-*,llvm-*,clang-analyzer-*',
        '--cross-file-rename',
      },
      filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
      on_attach = function(client, bufnr)
        client.server_capabilities.documentFormattingProvider = client.server_capabilities.documentFormattingProvider
          or true
        on_attach(client, bufnr)
      end,
    },
    rust_analyzer = {
      root_dir = function(fname)
        return util.root_pattern('Cargo.toml', 'rust-project.json', '.git')(fname) or util.path.dirname(fname)
      end,
      filetypes = { 'rust' },
      message_level = vim.lsp.protocol.MessageType.error,
      on_attach = on_attach,
      settings = {
        ['rust-analyzer'] = {
          cargo = { loadOutDirsFromCheck = true },
          procMacro = { enable = true },
        },
      },
      flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
    },
    sqls = {
      filetypes = { 'sql' },
      on_attach = function(client, _)
        client.server_capabilities.executeCommandProvider = client.server_capabilities.documentFormattingProvider
          or true
        highlight.diagnositc_config_sign()
        require('sqls').setup({ picker = 'telescope' }) -- or default
      end,
      flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
      settings = {
        cmd = { 'sqls', '-config', '$HOME/.config/sqls/config.yml' },
        -- alterantively:
        -- connections = {
        --   {
        --     driver = 'postgresql',
        --     datasourcename = 'host=127.0.0.1 port=5432 user=postgres password=password dbname=user_db sslmode=disable',
        --   },
        -- },
      },
    },

    pyright = {
      on_attach = on_attach,
      -- on_init = require('navigator.lspclient.python').on_init,
      on_init = function(client)
        require('navigator.lspclient.python').on_init(client)
      end,
      cmd = { 'pyright-langserver', '--stdio' },
      filetypes = { 'python' },
      flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
      settings = {
        python = {
          formatting = { provider = 'black' },
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = 'workspace',
          },
        },
      },
    },
    ccls = {
      on_attach = on_attach,
      init_options = {
        compilationDatabaseDirectory = 'build',
        root_dir = [[ util.root_pattern("compile_commands.json", "compile_flags.txt", "CMakeLists.txt", "Makefile", ".git") or util.path.dirname ]],
        index = { threads = 2 },
        clang = { excludeArgs = { '-frounding-math' } },
      },
      flags = { allow_incremental_sync = true },
    },
    jdtls = {
      settings = {
        java = { signatureHelp = { enabled = true }, contentProvider = { preferred = 'fernflower' } },
      },
    },
    omnisharp = {
      cmd = { 'omnisharp', '--languageserver', '--hostPID', tostring(vfn.getpid()) },
    },
    terraformls = {
      filetypes = { 'terraform', 'tf' },
    },

    sourcekit = {
      cmd = { 'sourcekit-lsp' },
      filetypes = { 'swift' }, -- This is recommended if you have separate settings for clangd.
    },
  }

  setups.lua_ls = require('navigator.lspclient.lua_ls').lua_ls()
  return setups
end

return M
