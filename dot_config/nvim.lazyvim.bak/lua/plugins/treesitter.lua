return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua",
        "javascript",
        "markdown",
        "angular",
        "css",
        "json",
        "scss",
      },
      auto_install = true,
    })
  end,
}
