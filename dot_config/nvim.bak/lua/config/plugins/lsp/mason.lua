return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"ts_ls",
					"html",
					"cssls",
					"angularls",
					"omnisharp",
					"lua_ls",
					"emmet_ls",
					"jsonls",
					"eslint",
					"stylelint_lsp",
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"jose-elias-alvarez/nvim-lsp-ts-utils",
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			local util = require("lspconfig.util")
			local lspconfig = require("lspconfig")
			local cmp_nvim_lsp = require("cmp_nvim_lsp")
			local keymap = vim.keymap

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
					keymap.set("n", "gR", vim.lsp.buf.references, opts) -- show definition, references
					keymap.set("n", "gr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references
					keymap.set("n", "gs", "<cmd>Telescope lsp_workspace_symbols<CR>", opts) -- show symbols
					keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations
					keymap.set("n", "gI", vim.lsp.buf.implementation, opts) -- show lsp implementations
					keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type doefinitions

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

			local capabilities = cmp_nvim_lsp.default_capabilities(vim.lsp.protocol.make_client_capabilities())

			lspconfig.lua_ls.setup({
				capabilities = capabilities,
			})

			lspconfig.ts_ls.setup({
				capabilities = capabilities,
				init_options = require("nvim-lsp-ts-utils").default_init_options,
			})

			lspconfig.cssls.setup({
				capabilities = capabilities,
			})

			lspconfig.angularls.setup({
				capabilities = capabilities,
				root_dir = util.root_pattern("angular.json", "project.json"),
			})

			lspconfig.eslint.setup({
				capabilities = capabilities,
				settings = {
					format = true,
					codeActionsOnSave = {
						sourceFixAll = true,
					},
				},
				dynamicRegistration = true,
				on_new_config = function(config, new_root_dir)
					config.settings.workspaceFilter = {
						uri = vim.loop.cwd(),
						name = vim.fn.fnamemodify(new_root_dir, ":t"),
					}
				end,
				workingDirectory = {
					mode = "auto",
				},
			})

			lspconfig.stylelint_lsp.setup({
				capabilities = capabilities,
				settings = {
					format = true,
				},
			})

			lspconfig.emmet_ls.setup({
				capabilities = capabilities,
			})

			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
		end,
	},
}
