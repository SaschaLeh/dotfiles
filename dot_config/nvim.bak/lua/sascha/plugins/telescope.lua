return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-telescope/telescope-ui-select.nvim",
		"nvim-tree/nvim-web-devicons",
		"ThePrimeagen/harpoon",
	},
	config = function()
		-- import telescope plugin safely
		local telescope = require("telescope")

		-- import telescope actions safely
		local actions = require("telescope.actions")

		-- import telescope-ui-select safely
		local themes = require("telescope.themes")
		local harpoon = require("harpoon.mark")
		local harpoonUi = require("harpoon.ui")

		-- configure telescope
		telescope.setup({
			-- configure custom mappings
			defaults = {
				path_display = {
					smart = "true",
					shorten = {
						len = 3,
						exclude = { 1, -1 },
					},
					truncate = true,
				},
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous, -- move to prev result
						["<C-j>"] = actions.move_selection_next, -- move to next result
						["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist, -- send selected to quickfixlist
					},
				},
				layout_strategy = "vertical",
				dynamic_preview_title = true,
				lsp_document_symbols = {
					fname_width = 160,
					show_line = true,
					symbol_width = 160,
				},
				file_ignore_patterns = {
					".git/",
					"backendApi/", -- make this load via exrc to project local
					"backend/", -- schweiz
					"Datenbank/", -- schweiz
					"Distribution/", -- schweiz
					"ISAG.NET/", -- schweiz
					"Build/", -- schweiz
					"Directory.Build.props/", -- schweiz
					"%.mat",
					"%.meta",
					"%.asset",
					"%.prefab",
					"%.shader",
					"%.cginc",
					"%.asmdef",
					"%.unity",
					".angular/",
				},
			},
			extensions = {
				["ui-select"] = {
					themes.get_dropdown({}),
				},
			},
		})

		telescope.load_extension("fzf")
		telescope.load_extension("ui-select")
		telescope.load_extension("harpoon")

		-- set keymaps
		local keymap = vim.keymap -- for conciseness

		keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" }) -- find files within current working directory, respects .gitignore
		keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" }) -- find previously opened files
		keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" }) -- find string in current working directory as you type
		keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" }) -- find string under cursor in current working directory
		keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Show open buffers" }) -- list open buffers in current neovim instance
		keymap.set("n", "<leader>gc", "<cmd>Telescope git_commits<cr>", { desc = "Show git commits" }) -- list all git commits (use <cr> to checkout) ["gc" for git commits]
		keymap.set(
			"n",
			"<leader>gfc",
			"<cmd>Telescope git_bcommits<cr>",
			{ desc = "Show git commits for current buffer" }
		) -- list git commits for current file/buffer (use <cr> to checkout) ["gfc" for git file commits]
		keymap.set("n", "<leader>gb", "<cmd>Telescope git_branches<cr>", { desc = "Show git branches" }) -- list git branches (use <cr> to checkout) ["gb" for git branch]
		keymap.set("n", "<leader>gs", "<cmd>Telescope git_status<cr>", { desc = "Show current git changes per file" }) -- list current changes per file with diff preview ["gs" for git status]
		keymap.set("n", "<leader>gf", "<cmd>Telescope git_files<cr>", { desc = "Show git files" }) -- list current changes per file with diff preview ["gs" for git status]

		keymap.set("n", "<leader>ha", harpoon.add_file, { desc = "Harpoon add Files" }) -- list current changes per file with diff preview ["gs" for git status]
		keymap.set("n", "<leader>hf", "<cmd>Telescope harpoon marks<cr>", { desc = "Show harpoon marks" }) -- show harpoon marks
		keymap.set("n", "<leader>j", harpoonUi.nav_next, { desc = "Harpoon Navigate next" }) -- show harpoon marks
		keymap.set("n", "<leader>k", harpoonUi.nav_prev, { desc = "Harpoon Navigate previous" }) -- show harpoon marks
		keymap.set("n", "<leader>hh", harpoonUi.toggle_quick_menu, { desc = "Harpoon Toggle Quick Menu" }) -- show harpoon marks
	end,
}
