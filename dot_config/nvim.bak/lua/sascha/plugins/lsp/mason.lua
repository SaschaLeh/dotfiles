return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		{
			"smjonas/inc-rename.nvim",
			config = true,
		},
		"neovim/nvim-lspconfig",
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		"hrsh7th/nvim-cmp",
		"L3MON4D3/LuaSnip",
		"nat-418/cmp-color-names.nvim",
		"saadparwaiz1/cmp_luasnip",
		"jose-elias-alvarez/nvim-lsp-ts-utils",
		{
			"smjonas/inc-rename.nvim",
			config = true,
		},
	},
	config = function()
		local mason = require("mason")
		local mason_lspconfig = require("mason-lspconfig")
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		mason.setup()
		mason_lspconfig.setup({
			ensure_installed = {
				"tsserver",
				"html",
				"cssls",
				"angularls",
				"omnisharp",
				"lua_ls",
				"emmet_ls",
				"jsonls",
				"eslint",
			},
			-- auto-install configured servers (with lspconfig)
			automatic_installation = true, -- not the same as ensure_installed
		})
		mason_lspconfig.setup_handlers({
			function(server_name) -- default handler (optional)
				require("lspconfig")[server_name].setup({
					capabilities = capabilities,
				})
			end,
		})

		-- KEYMAPS
		--
		local keymap = vim.keymap

		keymap.set("n", "<space>e", vim.diagnostic.open_float)
		keymap.set("n", "<space>q", vim.diagnostic.setloclist)

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Enable completion triggered by <c-x><c-o>
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf }
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
				keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions
				keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references
				keymap.set("n", "gs", "<cmd>Telescope lsp_workspace_symbols<CR>", opts) -- show symbols
				keymap.set("n", "gI", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations
				keymap.set("n", "gT", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type doefinitions

				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection
				keymap.set({ "n", "v" }, "<leader>cA", function()
					vim.lsp.buf.code_action({
						context = {
							only = {
								"source",
							},
							diagnostics = {},
						},
					})
				end, opts) -- see available code actions, in visual mode will apply to selection

				--Help
				keymap.set("n", "K", vim.lsp.buf.hover, opts)
				keymap.set("n", "gK", vim.lsp.buf.signature_help)

				--Diagnostics
				keymap.set("n", "<leader>rn", ":IncRename ", opts) -- smart rename
				keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file
				keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line
				keymap.set("n", "<leader>td", vim.lsp.buf.type_definition, opts)
				keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer
				keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer
				keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

				keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
				keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts)
				keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts)
				keymap.set("n", "<leader>wl", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, opts)
				keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
				keymap.set("n", "gr", vim.lsp.buf.references, opts)
				keymap.set("n", "<leader>f", function()
					vim.lsp.buf.format({ async = true })
				end, opts)

				keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
			end,
		})

		require("lspconfig").tsserver.setup({
			-- Needed for inlayHints. Merge this table with your settings or copy
			-- it from the source if you want to add your own init_options.
			init_options = require("nvim-lsp-ts-utils").init_options,
			--
			on_attach = function(client, bufnr)
				local ts_utils = require("nvim-lsp-ts-utils")

				-- defaults
				ts_utils.setup({
					debug = false,
					disable_commands = false,
					enable_import_on_completion = false,

					-- import all
					import_all_timeout = 5000, -- ms
					-- lower numbers = higher priority
					import_all_priorities = {
						same_file = 1, -- add to existing import statement
						local_files = 2, -- git files or files with relative path markers
						buffer_content = 3, -- loaded buffer content
						buffers = 4, -- loaded buffer names
					},
					import_all_scan_buffers = 100,
					import_all_select_source = false,
					-- if false will avoid organizing imports
					always_organize_imports = true,

					-- filter diagnostics
					filter_out_diagnostics_by_severity = {},
					filter_out_diagnostics_by_code = {},

					-- inlay hints
					auto_inlay_hints = true,
					inlay_hints_highlight = "Comment",
					inlay_hints_priority = 200, -- priority of the hint extmarks
					inlay_hints_throttle = 150, -- throttle the inlay hint request
					inlay_hints_format = { -- format options for individual hint kind
						Type = {},
						Parameter = {},
						Enum = {},
						-- Example format customization for `Type` kind:
						-- Type = {
						--     highlight = "Comment",
						--     text = function(text)
						--         return "->" .. text:sub(2)
						--     end,
						-- },
					},

					-- update imports on file move
					update_imports_on_move = false,
					require_confirmation_on_move = false,
					watch_dir = nil,
				})

				-- required to fix code action ranges and filter diagnostics
				ts_utils.setup_client(client)

				-- no default maps, so you may want to define some here
				local opts = { silent = true }
				vim.api.nvim_buf_set_keymap(bufnr, "n", "go", ":TSLspOrganize<CR>", opts)
				vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", ":TSLspRenameFile<CR>", opts)
				vim.api.nvim_buf_set_keymap(bufnr, "n", "ai", ":TSLspImportAll<CR>", opts)
			end,
		})
		-- Change the Diagnostic symbols in the sign column (gutter)
		-- (not in youtube nvim video)
		local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		--CMP
		--

		local cmp = require("cmp")

		cmp.setup({
			snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
			}),
			sources = cmp.config.sources({
				{ name = "nvim_lsp" },
				{ name = "luasnip" }, -- For luasnip users.
			}, {
				{ name = "buffer" },
			}),
		})

		-- Set configuration for specific filetype.
		cmp.setup.filetype("gitcommit", {
			sources = cmp.config.sources({
				{ name = "git" }, -- You can specify the `git` source if [you were installed it](https://github.com/petertriho/cmp-git).
			}, {
				{ name = "buffer" },
			}),
		})

		-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
		cmp.setup.cmdline({ "/", "?" }, {
			mapping = cmp.mapping.preset.cmdline(),
			sources = {
				{ name = "buffer" },
			},
		})

		-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({
				{ name = "path" },
			}, {
				{ name = "cmdline" },
			}),
		})

		-- Set up lspconfig.
		local capabilities = require("cmp_nvim_lsp").default_capabilities()
		-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
		require("lspconfig")["<YOUR_LSP_SERVER>"].setup({
			capabilities = capabilities,
		})
	end,
}
