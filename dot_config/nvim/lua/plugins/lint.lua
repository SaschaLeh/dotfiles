return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        css = { "stylelint" },
        scss = { "stylelint" },
      },
      linters = {
        -- Prefer project-local stylelint which has all plugins (e.g. postcss-scss)
        stylelint = {
          cmd = function()
            local local_bin = vim.fn.findfile("node_modules/.bin/stylelint", vim.fn.getcwd() .. ";")
            return local_bin ~= "" and local_bin or "stylelint"
          end,
        },
      },
    },
  },
  {
    "mason.nvim",
    opts = {
      ensure_installed = {
        "stylelint",
      },
    },
  },
}
