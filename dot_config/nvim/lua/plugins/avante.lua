return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	lazy = false,
	version = false, -- set this if you want to always pull the latest change
	keys = {
		{
			"<leader>acd",
			function()
				require("avante.api").ask({ question = "Add a JsDoc to this" })
			end,
			mode = { "n", "v" },
			desc = "avante: Add JSDoc string",
		},
		{
			"<leader>acg",
			function()
				require("avante.api").ask({ question = "Translate this to german" })
			end,
			mode = { "n", "v" },
			desc = "avnate: Translate to german",
		},
		{
			"<leader>af",
			"<cmd>AvanteFocus<cr>",
			desc = "avante: Focus/Unfocus Sidebar",
		},
	},
	opts = {
		-- Configure OpenRouter.ai as the provider
		provider = "openrouter",
		vendors = {
			openrouter = {
                 __inherited_from = "openai",
				api_key_name = "OPENROUTER_API_KEY", -- Recommended to use an environment variable
				endpoint = "https://openrouter.ai/api/v1",
				model = "anthropic/claude-3-haiku", -- Specific Claude Haiku model
				max_tokens = 4096,
			},
		},
	},
	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	build = "make",
	-- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
	dependencies = {
		"stevearc/dressing.nvim",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		--- The below dependencies are optional,
		"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
		"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
		"zbirenbaum/copilot.lua", -- for providers='copilot'
		{
			-- support for image pasting
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				-- recommended settings
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = {
						insert_mode = true,
					},
				},
			},
		},
		{
			-- Make sure to set this up properly if you have lazy=true
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
