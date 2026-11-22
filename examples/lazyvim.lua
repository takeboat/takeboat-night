-- LazyVim / lazy.nvim 插件 spec
-- 放到 ~/.config/nvim/lua/plugins/takeboat.lua 即可
return {
    {
        "takeboat/takeboat-night",
        name = "takeboat",
        priority = 1000,
        lazy = false,
        opts = {
            italic_comments = true,
            transparent = false,
            on_highlights = function(hl, c)
                -- 切窗口时编辑区不再「闪一下」
                hl.NormalNC = { fg = c.fg, bg = c.bg }
            end,
        },
        config = function(_, opts)
            require("takeboat").setup(opts)
            -- 纸：takeboat　夜：takeboat-night　黎明：takeboat-dawn
            vim.cmd.colorscheme("takeboat-night")
        end,
    },

    -- 让 LazyVim 也用它（lualine / snacks 等会跟着适配）
    {
        "LazyVim/LazyVim",
        opts = { colorscheme = "takeboat-night" },
    },
}
