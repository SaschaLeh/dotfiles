return {
    "sindrets/diffview.nvim",
    config = function()
        vim.keymap.set(
            "n",
            "<leader>gfh",
            "<cmd>DiffViewFileHistory %<CR>",
            { desc = "[DiffView] File History of current File" }
        )
        vim.keymap.set(
            "n",
            "<leader>gfH",
            "<cmd>DiffViewFileHistory<CR>",
            { desc = "[DiffView] File History of current Branch" }
        )
        vim.keymap.set(
            "n",
            "<leader>gdc",
            "<cmd>DiffviewClose<CR>",
            { desc = "[DiffView] Close current DiffView" }
        )
    end,
}
