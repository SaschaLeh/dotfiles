-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--NgSwitcher
vim.keymap.set("n", "<leader>ngt", "<cmd>NgSwitchTS<CR>", { desc = "NgSwitcher - Switch to TS" })
vim.keymap.set("n", "<leader>ngc", "<cmd>NgSwitchCSS<CR>", { desc = "NgSwitcher - Switch to CSS" })
vim.keymap.set("n", "<leader>ngh", "<cmd>NgSwitchHTML<CR>", { desc = "NgSwitcher - Switch to HTML" })

--Blamer
vim.keymap.set("n", "<leader>bb", "<cmd>BlamerToggle<CR>", { desc = "Toggle Blamer" })
vim.keymap.set("n", "<leader>rs", "<cmd>LspRestart<CR>", { desc = "Restart LSP" })

-- Move
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

--Paste without losinig current buffer
vim.keymap.set("x", "<leader>p", '"_dp', { desc = "Paste without losing current buffer" })

--Keep Cursor in middle while jumping
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
