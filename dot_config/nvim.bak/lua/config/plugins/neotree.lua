return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
	},
	config = function()
		require("neo-tree").setup({
			filesystem = {
				follow_current_file = true,
				hijack_netrw_behavior = "open_current",
				use_libuv_file_watcher = true,
			},
		})

		vim.keymap.set("n", "<leader>e", function()
			require("neo-tree.command").execute({ toggle = true, dir = vim.fn.getcwd() })
		end, { desc = "Show Neotree" })
	end,
}
