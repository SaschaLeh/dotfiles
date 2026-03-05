return {
	"ThePrimeagen/harpoon",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = function()
		require("harpoon").setup()
		local harpoon = require("harpoon")
		local mark = require("harpoon.mark")
		local ui = require("harpoon.ui")

		-- Optional: Key mappings for Harpoon functionality
		vim.keymap.set("n", "<leader>ha", mark.add_file, { desc = "Add file to Harpoon" })
		vim.keymap.set("n", "<leader>hh", ui.toggle_quick_menu, { desc = "Toggle Harpoon quick menu" })
	end,
}
