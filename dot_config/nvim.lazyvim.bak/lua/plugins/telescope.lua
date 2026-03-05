return {

  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-live-grep-args.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "CFLAGS=-march=native make",
        lazy = true,
      },
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      {
        "<leader>f/",
        ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>",
        desc = "Grep string",
      },
    },
    opts = {
      extensions_list = { "fzf" },
      extensions = {
        fzf = {
          fuzzy = true, -- false will only do exact matching
          override_generic_sorter = true, -- override the generic sorter
          override_file_sorter = true, -- override the file sorter
          case_mode = "smart_case", -- or "ignore_case" or "respect_case"
          -- the default case_mode is "smart_case"
        },
      },
      defaults = {
        lsp_document_symbols = {
          fname_width = 160,
          show_line = true,
          symbol_width = 160,
        },
        dynamic_preview_title = true,
        path_display = {
          smart = "true",
          shorten = {
            len = 3,
            exclude = { 1, -1 },
          },
          truncate = true,
        },
        show_line = true,
        fname_width = 160,
        layout_strategy = "vertical",
        layout_config = {
          prompt_position = "top",
          vertical = { width = 0.9 },
          horizontal = { width = 0.9 },
        },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },
}
