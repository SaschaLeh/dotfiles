return {
	"APZelos/blamer.nvim",
	config = function()
		vim.keymap.set("n", "<leader>bb", "<cmd>BlamerToggle<CR>")
	end,
}
