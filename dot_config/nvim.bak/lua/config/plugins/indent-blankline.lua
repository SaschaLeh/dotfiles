return {
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	opts = {},
	config = function()
		require("ibl").setup({
			exclude = {
				filetypes = {
					"alpha", -- Exclude alpha dashboard
					"help", -- Optional: exclude help buffers
					"dashboard", -- Optional: any additional dashboards
					"NvimTree", -- Optional: NvimTree or other tree navigators
				},
			},
		})
	end,
}
