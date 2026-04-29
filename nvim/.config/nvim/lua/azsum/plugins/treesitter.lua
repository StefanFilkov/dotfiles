local parsers = {
  "bash",
  "dockerfile",
  "gitignore",
  "hcl",
  "javascript",
  "jsdoc",
  "json",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "regex",
  "terraform",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local cargo_bin = vim.fn.expand("~/.cargo/bin")

    if vim.fn.executable("tree-sitter") == 0 and vim.uv.fs_stat(cargo_bin .. "/tree-sitter") then
      vim.env.PATH = cargo_bin .. ":" .. vim.env.PATH
    end

    require("nvim-treesitter").setup()

    if vim.fn.executable("tree-sitter") == 1 then
      require("nvim-treesitter").install(parsers)
    end

    vim.treesitter.language.register("bash", "sh")
    vim.treesitter.language.register("json", "jsonc")
    vim.treesitter.language.register("jsx", "javascriptreact")
    vim.treesitter.language.register("terraform", "terraform-vars")
    vim.treesitter.language.register("tsx", "typescriptreact")

    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "bash",
        "dockerfile",
        "gitignore",
        "hcl",
        "javascript",
        "javascriptreact",
        "json",
        "jsonc",
        "lua",
        "markdown",
        "python",
        "sh",
        "terraform",
        "terraform-vars",
        "toml",
        "typescript",
        "typescriptreact",
        "vim",
        "yaml",
      },
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "bash",
        "dockerfile",
        "hcl",
        "javascript",
        "javascriptreact",
        "json",
        "jsonc",
        "lua",
        "python",
        "sh",
        "terraform",
        "terraform-vars",
        "toml",
        "typescript",
        "typescriptreact",
        "vim",
        "yaml",
      },
      callback = function(args)
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
