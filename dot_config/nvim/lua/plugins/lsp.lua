local util = require("lspconfig.util")

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      loglevel = "debug",
      inlay_hints = {
        enabled = false,
        exclude = {}, -- filetypes for which you don't want to enable inlay hints
      },
      servers = {
        html = {

          hover = {
            documentation = true,
            references = true,
          },
        },
        angularls = {
          root_dir = util.root_pattern("angular.json", "project.json"),
        },
        eslint = {
          debug = true,
          dynamicRegistration = true,
          on_new_config = function(new_config, new_root_dir)
            new_config.settings.workspaceFolder = {
              uri = vim.loop.cwd(),
              name = vim.fn.fnamemodify(new_root_dir, ":t"),
            }
          end,
          workingDirectory = {
            mode = "auto",
          },
        },
        tsserver = {
          init_options = {
            preferences = {
              organizeImportsIgnoreCase = true,
              importModuleSpecifierPreference = "relative",
              importModuleSpecifierEnding = "minimal",
            },
          },
          debug = false,
          disable_commands = false,
          enable_import_on_completion = true,
          importModuleSpecifierPreference = "relative",
          -- import all
          import_all_timeout = 5000, -- ms
          -- lower numbers = higher priority
          import_all_priorities = {
            same_file = 1, -- add to existing import statement
            local_files = 2, -- git files or files with relative path markers
            buffer_content = 3, -- loaded buffer content
            buffers = 4, -- loaded buffer names
          },
          import_all_scan_buffers = 100,
          import_all_select_source = false,
          -- if false will avoid organizing imports
          always_organize_imports = true,
          -- filter diagnostics
          filter_out_diagnostics_by_severity = {},
          filter_out_diagnostics_by_code = {},
          -- inlay hints
          auto_inlay_hints = false,
          inlay_hints_highlight = "Comment",
          inlay_hints_priority = 200, -- priority of the hint extmarks
          inlay_hints_throttle = 150, -- throttle the inlay hint request
          inlay_hints_format = {
            -- format options for individual hint kind
            Type = {},
            Parameter = {},
            Enum = {},
            -- Example format customization for `Type` kind:
            -- Type = {
            --     highlight = "Comment",
            --     text = function(text)
            --         return "->" .. text:sub(2)
            --     end,
            -- },
          },
          -- update imports on file move
          update_imports_on_move = false,
          require_confirmation_on_move = false,
          watch_dir = nil,
        },
      },
    },
  },
}
