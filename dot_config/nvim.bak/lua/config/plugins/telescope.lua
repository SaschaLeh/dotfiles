return {
	{
		"nvim-telescope/telescope-ui-select.nvim",
	},
	{
		"nvim-telescope/telescope-fzf-native.nvim",
	},
	{
		"nvim-telescope/telescope.nvim",
		build = "make",
		config = function()
			require("telescope").setup({
				defaults = {
					layout_strategy = "center",
					path_display = { filename_first = { reverse_directories = false } },
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
					fzf = {
						fuzzy = true, -- false will only do exact matching
						override_generic_sorter = true, -- override the generic sorter
						override_file_sorter = true, -- override the file sorter
						case_mode = "smart_case", -- or "ignore_case" or "respect_case"
						-- the default case_mode is "smart_case"
					},
				},
			})
			require("telescope").load_extension("ui-select")
			require("telescope").load_extension("fzf")

			-- set keymaps
			local keymap = vim.keymap -- for conciseness

			keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" }) -- find files within current working directory, respects .gitignore
			keymap.set("n", "<leader><leader>", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" }) -- find files within current working directory, respects .gitignore
			keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" }) -- find previously opened files
			keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" }) -- find string in current working directory as you type
			keymap.set("n", "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Find Keymaps" }) -- find string in current working directory as you type
			keymap.set(
				"n",
				"<leader>sd",
				"<cmd>Telescope diagnostics<cr>",
				{ desc = "Show Diagnostics for current buffer" }
			) -- find string in current working directory as you type
			keymap.set(
				"n",
				"<leader>fc",
				"<cmd>Telescope grep_string<cr>",
				{ desc = "Find string under cursor in cwd" }
			) -- find string under cursor in current working directory
			keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Show open buffers" }) -- list open buffers in current neovim instance
			keymap.set("n", "<leader>fgc", "<cmd>Telescope git_commits<cr>", { desc = "Show git commits" }) -- list all git commits (use <cr> to checkout) ["gc" for git commits]
			keymap.set(
				"n",
				"<leader>gfc",
				"<cmd>Telescope git_bcommits<cr>",
				{ desc = "Show git commits for current buffer" }
			) -- list git commits for current file/buffer (use <cr> to checkout) ["gfc" for git file commits]
			keymap.set("n", "<leader>gb", "<cmd>Telescope git_branches<cr>", { desc = "Show git branches" }) -- list git branches (use <cr> to checkout) ["gb" for git branch]
			keymap.set(
				"n",
				"<leader>gs",
				"<cmd>Telescope git_status<cr>",
				{ desc = "Show current git changes per file" }
			) -- list current changes per file with diff preview ["gs" for git status]
			keymap.set("n", "<leader>gf", "<cmd>Telescope git_files<cr>", { desc = "Show git files" }) -- list current changes per file with diff preview ["gs" for git status]
		end,
	},
}
