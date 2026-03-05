return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    opts.ensure_installed = opts.ensure_installed or {}
    vim.list_extend(opts.ensure_installed, {
      "angular", "css", "scss", "javascript", "typescript",
      "json", "lua", "markdown",
    })
  end,
}
