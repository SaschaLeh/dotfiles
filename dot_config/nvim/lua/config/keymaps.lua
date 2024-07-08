-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local harpoonUi = require("harpoon.ui")

--NgSwitcher
vim.keymap.set("n", "<leader>u", "<cmd>NgSwitchTS<CR>", { desc = "NgSwitcher - Switch to TS" })
vim.keymap.set("n", "<leader>i", "<cmd>NgSwitchCSS<CR>", { desc = "NgSwitcher - Switch to CSS" })
vim.keymap.set("n", "<leader>o", "<cmd>NgSwitchHTML<CR>", { desc = "NgSwitcher - Switch to HTML" })

--Blamer
vim.keymap.set("n", "<leader>bb", "<cmd>BlamerToggle<CR>", { desc = "Toggle Blamer" })
vim.keymap.set("n", "<leader>rs", "<cmd>LspRestart<CR>", { desc = "Restart LSP" })

-- Diffview
vim.keymap.set("n", "<leader>fh", "<cmd>DiffviewFileHistory %<CR>", { desc = "Git File History" })

-- Import handling
vim.keymap.set("n", "<leader>oi", function()
  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" } },
    apply = true,
  })
end, { desc = "Organize Imports" })

-- Move
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

--Paste without losinig current buffer
vim.keymap.set("x", "<leader>p", '"_dp', { desc = "Paste without losing current buffer" })

--harpoon
vim.keymap.set("n", "<leader>hh", function()
  harpoonUi.toggle_quick_menu()
end, { desc = "Harpoon - Toggle UI" })

vim.keymap.set("n", "<leader>ha", function()
  require("harpoon.mark").add_file()
end, { desc = "Harpoon - Add File" })

vim.keymap.set("n", "<leader>hj", function()
  harpoonUi.nav_next()
end, { desc = "Harpoon - Navigate next File" })

vim.keymap.set("n", "<leader>hk", function()
  harpoonUi.nav_prev()
end, { desc = "Harpoon - Navigate previous File" })
