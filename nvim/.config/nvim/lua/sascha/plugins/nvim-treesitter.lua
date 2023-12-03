return {
	{
		"nvim-treesitter/nvim-treesitter",
		event = { "BufReadPre", "BufNewFile" },
		build = ":TSUpdate",
		dependencies = {
			"windwp/nvim-ts-autotag",
			"p00f/nvim-ts-rainbow",
		},
		config = function()
			-- import nvim-treesitter plugin
			local treesitter = require("nvim-treesitter.configs")

			local commentstring = require("ts_context_commentstring")

			-- configure treesitter
			commentstring.setup({})
			treesitter.setup({ -- enable syntax highlighting
				highlight = {
					enable = true,
				},
				rainbow = {
					enable = true,
					max_file_lines = nil,
				},
				-- enable indentation
				indent = { enable = true },
				-- enable autotagging (w/ nvim-ts-autotag plugin)
				autotag = { enable = true },
				-- ensure these language parsers are installed
				ensure_installed = {
					"json",
					"javascript",
					"typescript",
					"yaml",
					"html",
					"css",
					"markdown",
					"markdown_inline",
					"bash",
					"lua",
					"vim",
					"dockerfile",
					"gitignore",
					"scss",
				},
				-- auto install above language parsers
				auto_install = true,
			})
			vim.g.skip_ts_context_commentstring_module = true
		end,
	},
}
