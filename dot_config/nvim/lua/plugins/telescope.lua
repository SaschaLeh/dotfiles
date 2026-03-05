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
          filename_first = { reverse_directories = false },
        },
        show_line = true,
        fname_width = 160,
        layout_strategy = "center",
      },
    },
  },
}
