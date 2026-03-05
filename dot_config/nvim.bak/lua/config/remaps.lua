-- Remaps NG-SWITCHER
vim.keymap.set("n", "<leader>u", "<cmd>NgSwitchTS<CR>", { desc = "NgSwitcher - Switch to TS" })
vim.keymap.set("n", "<leader>i", "<cmd>NgSwitchCSS<CR>", { desc = "NgSwitcher - Switch to CSS" })
vim.keymap.set("n", "<leader>o", "<cmd>NgSwitchHTML<CR>", { desc = "NgSwitcher - Switch to HTML" })

-- Move
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

--Cursor Stays when using J
vim.keymap.set("n", "J", "mzJ`z")

--Keep Cursor in middle while jumping
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

--Keep in middle while searching
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

--Keep in middle while searching
vim.keymap.set("n", "<leader>l", "<cmd>Lazy<CR>")

--quit
vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

--Paste without losinig current buffer
vim.keymap.set("x", "<leader>p", '"_dp')

-- Import handling
vim.keymap.set("n", "<leader>oi", function()
	vim.lsp.buf.code_action({
		context = { only = { "source.organizeImports" } },
		apply = true,
	})
end, { desc = "Organize Imports" })
