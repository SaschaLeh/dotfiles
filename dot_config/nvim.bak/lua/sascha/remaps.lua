-- Remaps NG-SWITCHER
vim.keymap.set("n", "<leader>u", ":<C-u>NgSwitchTS<CR>")

vim.keymap.set("n", "<leader>i", ":<C-u>NgSwitchCSS<CR>")
vim.keymap.set("n", "<leader>o", ":<C-u>NgSwitchHTML<CR>")
vim.keymap.set("n", "<leader>p", ":<C-u>NgSwitchSpec<CR>")

--with horizontal split
vim.keymap.set("n", "<leader>su", ":<C-u>SNgSwitchTS<CR>")
vim.keymap.set("n", "<leader>si", ":<C-u>SNgSwitchCSS<CR>")
vim.keymap.set("n", "<leader>so", ":<C-u>SNgSwitchHTML<CR>")
vim.keymap.set("n", "<leader>sp", ":<C-u>SNgSwitchSpec<CR>")

--with vertical split
vim.keymap.set("n", "<leader>vu", ":<C-u>VNgSwitchTS<CR>")
vim.keymap.set("n", "<leader>vi", ":<C-u>VNgSwitchCSS<CR>")
vim.keymap.set("n", "<leader>vo", ":<C-u>VNgSwitchHTML<CR>")
vim.keymap.set("n", "<leader>vp", ":<C-u>VNgSwitchSpec<CR>")

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

--Paste without losinig current buffer
vim.keymap.set("x", "<leader>p", "\"_dp")