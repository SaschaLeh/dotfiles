return {
  "ThePrimeagen/harpoon",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = function()
    require("harpoon").setup()
  end,
}
