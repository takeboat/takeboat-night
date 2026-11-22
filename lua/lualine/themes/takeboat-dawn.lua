-- lualine 主题：takeboat-dawn（黎明）

local p = require("takeboat.palette").dawn

local M = {
  normal = {
    a = { fg = p.bg, bg = p.red, gui = "bold" },
    b = { fg = p.fg_dim, bg = p.bg_alt },
    c = { fg = p.muted, bg = p.bg_soft },
  },
  insert = {
    a = { fg = p.bg, bg = p.green, gui = "bold" },
    b = { fg = p.fg_dim, bg = p.bg_alt },
    c = { fg = p.muted, bg = p.bg_soft },
  },
  visual = {
    a = { fg = p.bg, bg = p.indigo, gui = "bold" },
    b = { fg = p.fg_dim, bg = p.bg_alt },
    c = { fg = p.muted, bg = p.bg_soft },
  },
  replace = {
    a = { fg = p.bg, bg = p.ochre, gui = "bold" },
    b = { fg = p.fg_dim, bg = p.bg_alt },
    c = { fg = p.muted, bg = p.bg_soft },
  },
  command = {
    a = { fg = p.bg, bg = p.plum, gui = "bold" },
    b = { fg = p.fg_dim, bg = p.bg_alt },
    c = { fg = p.muted, bg = p.bg_soft },
  },
  terminal = {
    a = { fg = p.bg, bg = p.teal, gui = "bold" },
    b = { fg = p.fg_dim, bg = p.bg_alt },
    c = { fg = p.muted, bg = p.bg_soft },
  },
  inactive = {
    a = { fg = p.muted, bg = p.bg_alt },
    b = { fg = p.muted, bg = p.bg_alt },
    c = { fg = p.muted, bg = p.bg_alt },
  },
}

return M
