vim.g.mapleader = " "
vim.g.maplocalleader = " "

local custom_sections = {
  {
    title = "Files And Search",
    maps = {
      { lhs = "<leader>pv", desc = "Open file explorer", rhs = vim.cmd.Ex },
      { lhs = "<leader>ff", desc = "Find files", rhs = function() require("telescope.builtin").find_files() end },
      { lhs = "<leader>fg", desc = "Live grep", rhs = function() require("telescope.builtin").live_grep() end },
      { lhs = "<leader>fb", desc = "List open buffers", rhs = function() require("telescope.builtin").buffers() end },
      { lhs = "<leader>fh", desc = "Search help tags", rhs = function() require("telescope.builtin").help_tags() end },
    },
  },
  {
    title = "Git",
    maps = {
      { lhs = "<leader>gs", desc = "Git status", rhs = "<cmd>Git<cr>" },
      { lhs = "<leader>gd", desc = "Git diff split", rhs = "<cmd>Gvdiffsplit<cr>" },
      { lhs = "<leader>gb", desc = "Git blame", rhs = "<cmd>Gblame<cr>" },
      { lhs = "<leader>gw", desc = "Stage current file", rhs = "<cmd>Gwrite<cr>" },
    },
  },
  {
    title = "Harpoon",
    maps = {
      { lhs = "<leader>ha", desc = "Harpoon add file", rhs = function() require("harpoon.mark").add_file() end },
      { lhs = "<leader>hm", desc = "Harpoon menu", rhs = function() require("harpoon.ui").toggle_quick_menu() end },
      { lhs = "<leader>1", desc = "Harpoon file 1", rhs = function() require("harpoon.ui").nav_file(1) end },
      { lhs = "<leader>2", desc = "Harpoon file 2", rhs = function() require("harpoon.ui").nav_file(2) end },
      { lhs = "<leader>3", desc = "Harpoon file 3", rhs = function() require("harpoon.ui").nav_file(3) end },
      { lhs = "<leader>4", desc = "Harpoon file 4", rhs = function() require("harpoon.ui").nav_file(4) end },
    },
  },
  {
    title = "Treesitter",
    maps = {
      { lhs = "<leader>tp", desc = "Toggle playground", rhs = "<cmd>TSPlaygroundToggle<cr>" },
      { lhs = "<leader>tc", desc = "Show capture under cursor", rhs = "<cmd>TSHighlightCapturesUnderCursor<cr>" },
    },
  },
  {
    title = "Terminal",
    maps = {
      {
        lhs = "<leader>tt",
        desc = "Open terminal split",
        rhs = function()
          vim.cmd("botright 12split")
          vim.cmd.terminal()
          vim.cmd.startinsert()
        end,
      },
    },
  },
  {
    title = "History And Windows",
    maps = {
      { lhs = "<leader>u", desc = "Toggle undotree", rhs = "<cmd>UndotreeToggle<cr>" },
      { lhs = "<C-h>", desc = "Focus left split", rhs = "<C-w>h" },
      { lhs = "<C-j>", desc = "Focus lower split", rhs = "<C-w>j" },
      { lhs = "<C-k>", desc = "Focus upper split", rhs = "<C-w>k" },
      { lhs = "<C-l>", desc = "Focus right split", rhs = "<C-w>l" },
    },
  },
}

local terminal_navigation = {
  { lhs = "<C-h>", desc = "Focus left split from terminal", rhs = [[<C-\><C-n><C-w>h]] },
  { lhs = "<C-j>", desc = "Focus lower split from terminal", rhs = [[<C-\><C-n><C-w>j]] },
  { lhs = "<C-k>", desc = "Focus upper split from terminal", rhs = [[<C-\><C-n><C-w>k]] },
  { lhs = "<C-l>", desc = "Focus right split from terminal", rhs = [[<C-\><C-n><C-w>l]] },
}

local useful_builtins = {
  { lhs = "*", desc = "Search word under cursor forward" },
  { lhs = "%", desc = "Jump to matching bracket or pair" },
  { lhs = ".", desc = "Repeat the last change" },
  { lhs = "ciw", desc = "Change the current word" },
  { lhs = "ci\"", desc = "Change inside double quotes" },
  { lhs = "da(", desc = "Delete around parentheses" },
  { lhs = "f<char>", desc = "Jump to a character on this line" },
  { lhs = "t<char>", desc = "Jump right before a character" },
  { lhs = "g; / g,", desc = "Jump older or newer in change list" },
  { lhs = "zz", desc = "Center the cursor line" },
  { lhs = ":%s/old/new/gc", desc = "Replace in file with confirmation" },
  { lhs = ":copen", desc = "Open the quickfix list" },
}

local function close_window(win)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local function build_reference_lines()
  local lines = {
    "Key Reference",
    "q or <Esc> closes this window",
    "",
  }

  for _, section in ipairs(custom_sections) do
    table.insert(lines, section.title)
    for _, map in ipairs(section.maps) do
      table.insert(lines, string.format("  %-24s %s", map.lhs, map.desc))
    end
    table.insert(lines, "")
  end

  table.insert(lines, "Useful Built-ins")
  for _, tip in ipairs(useful_builtins) do
    table.insert(lines, string.format("  %-24s %s", tip.lhs, tip.desc))
  end

  return lines
end

local function show_reference()
  local lines = build_reference_lines()
  local width = 0

  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  width = math.min(math.max(width + 4, 72), vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = true
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = "Mappings",
    title_pos = "center",
  })

  vim.wo[win].cursorline = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false

  vim.keymap.set("n", "q", function() close_window(win) end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", function() close_window(win) end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<leader><leader><leader>", function() close_window(win) end, { buffer = buf, silent = true })
end

table.insert(custom_sections, {
  title = "Reference",
  maps = {
    { lhs = "<leader><leader><leader>", desc = "Show this key reference", rhs = show_reference },
  },
})

for _, section in ipairs(custom_sections) do
  for _, map in ipairs(section.maps) do
    vim.keymap.set(map.mode or "n", map.lhs, map.rhs, { desc = map.desc, silent = true })
  end
end

for _, map in ipairs(terminal_navigation) do
  vim.keymap.set("t", map.lhs, map.rhs, { desc = map.desc, silent = true })
end
