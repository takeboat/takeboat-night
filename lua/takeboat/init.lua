-- takeboat.nvim
-- 一个从「纸与墨」里长出来的 Neovim 配色：纸 #f2efe7、墨 #14130e、朱印 #a3382a。
-- 三套：takeboat（纸，light） / takeboat-night（夜，dark） / takeboat-dawn（夜，底色亮一档）。
--
-- 不依赖任何插件，LazyVim / 原生 nvim 均可直接用。

local api = vim.api
local P = require("takeboat.palette")

local M = {}

M.defaults = {
  -- 透明背景：Normal / NormalNC / 行号列透明，浮窗保留底色
  transparent = false,
  -- 注释斜体（墨色里斜体很像手写批注）
  italic_comments = true,
  -- 关键字加粗（默认关，宋体式克制）
  bold_keywords = false,
  -- 非当前窗口降低对比度：只压前景（fg → muted），底色始终与 Normal 一致。
  -- 不能把底色换成浮层色 bg_alt —— 深色档里 bg_alt 比 Normal 更亮，
  -- 焦点一移开整块编辑区会「亮一下」，看起来像闪屏。
  dim_inactive = false,
  -- 覆盖钩子：function(hl, colors) ... end
  on_highlights = nil,
}

M.config = {}
for k, v in pairs(M.defaults) do
  M.config[k] = v
end

---------------------------------------------------------------------------
-- utils
---------------------------------------------------------------------------

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

-- 把 fg 以 alpha 叠在 bg 上，得到不透明的十六进制色
local function blend(fg_hex, bg_hex, alpha)
  local fr, fg, fb = rgb(fg_hex)
  local br, bg, bb = rgb(bg_hex)
  local r = math.floor(fr * alpha + br * (1 - alpha) + 0.5)
  local g = math.floor(fg * alpha + bg * (1 - alpha) + 0.5)
  local b = math.floor(fb * alpha + bb * (1 - alpha) + 0.5)
  return string.format("#%02x%02x%02x", r, g, b)
end

local function mix(c1, c2)
  return blend(c1, c2, 0.5)
end

---------------------------------------------------------------------------
-- palette resolve
---------------------------------------------------------------------------

-- 每个 style 的元信息：colors_name / background / 亮度参数档位（alphas）
local STYLES = {
  paper = { name = "takeboat", background = "light", alphas = "paper" },
  night = { name = "takeboat-night", background = "dark", alphas = "night" },
  dawn = { name = "takeboat-dawn", background = "dark", alphas = "night" },
}

local term = {
  paper = {
    "#3f3d33", "#a3382a", "#4a5c3a", "#8a5a24",
    "#2f4a6b", "#6d3f52", "#2c5a58", "#d7d1c0",
    "#8d8879", "#c2664f", "#5f7448", "#a8742f",
    "#3f5f86", "#87566b", "#3d7370", "#f2efe7",
  },
  night = {
    "#2b2b25", "#d2604a", "#a6c07e", "#dcae6a",
    "#8fb2dc", "#c38fa5", "#7fbcb4", "#c9c4b7",
    "#6f6d62", "#e07a63", "#b7cf92", "#e8bf80",
    "#a3c2e6", "#d0a3b8", "#93cbc3", "#f5f2ea",
  },
}

local function resolve(style)
  local meta = STYLES[style] or STYLES.paper
  local p = P[style] or P.paper
  -- alphas：派生色（光标行/选区/半透明底）用的亮度档位，dawn 跟 night 共用一档
  local dark = meta.background == "dark"
  local night = meta.alphas == "night"
  local c = {}
  for k, v in pairs(p) do
    c[k] = v
  end

  c.style = STYLES[style] and style or "paper"
  c.background = meta.background
  c.is_night = dark
  c.name = meta.name

  c.cursorline = blend(p.fg, p.bg, night and 0.070 or 0.045)
  c.column     = blend(p.fg, p.bg, night and 0.050 or 0.032)
  c.search     = blend(p.ochre, p.bg, night and 0.300 or 0.340)
  c.match      = blend(p.ochre, p.bg, night and 0.200 or 0.180)

  c.tint_red    = blend(p.red, p.bg, night and 0.150 or 0.110)
  c.tint_ochre  = blend(p.ochre, p.bg, night and 0.150 or 0.120)
  c.tint_indigo = blend(p.indigo, p.bg, night and 0.160 or 0.110)
  c.tint_green  = blend(p.green, p.bg, night and 0.160 or 0.120)
  c.tint_teal   = blend(p.teal, p.bg, night and 0.160 or 0.110)
  c.tint_plum   = blend(p.plum, p.bg, night and 0.160 or 0.110)

  c.diff_add    = blend(p.green, p.bg, night and 0.170 or 0.150)
  c.diff_del    = blend(p.red, p.bg, night and 0.170 or 0.130)
  c.diff_change = blend(p.indigo, p.bg, night and 0.170 or 0.120)
  c.diff_text   = blend(p.ochre, p.bg, night and 0.260 or 0.300)

  -- faint：「次要但仍需读清」的一档（隐藏文件、dotfile）。
  -- 夹在 muted 与 fg_dim 中间：明显低于普通文件名，又不至于像 muted 那样暗。
  c.faint = mix(p.muted, p.fg_dim)

  c.border = c.line
  c.pmenu_sel = night and mix(p.bg_soft, p.sel) or p.sel
  c.term = term[meta.alphas] or term.paper

  return c
end

---------------------------------------------------------------------------
-- highlights
---------------------------------------------------------------------------

local function make_groups(c, o)
  local H = {}
  local function g(name, spec)
    H[name] = spec
  end

  local kw_bold = o.bold_keywords and true or nil
  local comment_italic = o.italic_comments and true or nil
  local normal_bg = o.transparent and "NONE" or c.bg
  -- 非当前窗口：底色永远跟 Normal 相同（原因见 defaults 里 dim_inactive 的注释），
  -- 想区分只降前景对比度，绝不换底色。
  local normal_nc_fg = o.dim_inactive and c.muted or c.fg

  -------------------------------------------------------------------------
  -- 基础界面
  -------------------------------------------------------------------------
  g("Normal", { fg = c.fg, bg = normal_bg })
  g("NormalNC", { fg = normal_nc_fg, bg = normal_bg })
  g("NormalFloat", { fg = c.fg, bg = c.bg_alt })
  g("FloatBorder", { fg = c.line, bg = c.bg_alt })
  g("FloatTitle", { fg = c.red, bg = c.bg_alt, bold = true })
  g("FloatFooter", { fg = c.muted, bg = c.bg_alt })

  g("Cursor", { fg = c.bg, bg = c.fg })
  g("lCursor", { fg = c.bg, bg = c.fg })
  g("CursorIM", { fg = c.bg, bg = c.fg })
  g("TermCursor", { fg = c.bg, bg = c.fg })
  g("TermCursorNC", { fg = c.bg, bg = c.muted })

  g("CursorLine", { bg = c.cursorline })
  g("CursorColumn", { bg = c.column })
  g("ColorColumn", { bg = c.column })
  g("CursorLineNr", { fg = c.red, bold = true })
  g("LineNr", { fg = c.muted })
  g("LineNrAbove", { fg = c.muted })
  g("LineNrBelow", { fg = c.muted })
  g("SignColumn", { bg = o.transparent and "NONE" or c.bg })
  g("FoldColumn", { fg = c.muted, bg = o.transparent and "NONE" or c.bg })
  g("Folded", { fg = c.muted, bg = c.bg_soft })
  g("EndOfBuffer", { fg = o.transparent and "NONE" or c.bg, bg = o.transparent and "NONE" or c.bg })

  g("VertSplit", { fg = c.line })
  g("WinSeparator", { fg = c.line })
  g("WinBar", { fg = c.fg_dim, bold = true })
  g("WinBarNC", { fg = c.muted })

  g("StatusLine", { fg = c.fg_dim, bg = c.bg_alt })
  g("StatusLineNC", { fg = c.muted, bg = c.bg_alt })
  g("StatusLineTerm", { fg = c.fg_dim, bg = c.bg_alt })
  g("StatusLineTermNC", { fg = c.muted, bg = c.bg_alt })

  g("TabLine", { fg = c.muted, bg = c.bg_alt })
  g("TabLineFill", { bg = c.bg_alt })
  g("TabLineSel", { fg = c.fg, bg = c.bg, bold = true })

  g("Pmenu", { fg = c.fg_dim, bg = c.bg_alt })
  g("PmenuSel", { fg = c.fg, bg = c.pmenu_sel, bold = true })
  g("PmenuKind", { fg = c.indigo, bg = c.bg_alt })
  g("PmenuKindSel", { fg = c.indigo, bg = c.pmenu_sel })
  g("PmenuExtra", { fg = c.muted, bg = c.bg_alt })
  g("PmenuExtraSel", { fg = c.muted, bg = c.pmenu_sel })
  g("PmenuMatch", { fg = c.red, bg = c.bg_alt, bold = true })
  g("PmenuMatchSel", { fg = c.red, bg = c.pmenu_sel, bold = true })
  g("PmenuSbar", { bg = c.bg_soft })
  g("PmenuThumb", { bg = c.line })
  g("PmenuBorder", { fg = c.line, bg = c.bg_alt })

  g("Visual", { bg = c.sel })
  g("VisualNOS", { bg = c.sel })
  g("Search", { fg = c.fg, bg = c.search })
  g("IncSearch", { fg = c.bg, bg = c.red, bold = true })
  g("CurSearch", { link = "IncSearch" })
  g("Substitute", { fg = c.fg, bg = c.diff_text })
  g("MatchParen", { fg = c.red, bg = c.bg_soft, bold = true })
  g("QuickFixLine", { bg = c.sel })
  g("WildMenu", { fg = c.fg, bg = c.pmenu_sel })

  g("MsgArea", { fg = c.fg_dim })
  g("ErrorMsg", { fg = c.red })
  g("WarningMsg", { fg = c.ochre })
  g("ModeMsg", { fg = c.fg, bold = true })
  g("MoreMsg", { fg = c.green })
  g("Question", { fg = c.indigo })
  g("Title", { fg = c.red, bold = true })
  g("Directory", { fg = c.indigo })
  g("NonText", { fg = c.line })
  g("SpecialKey", { fg = c.muted })
  g("Whitespace", { fg = c.line })
  g("Conceal", { fg = c.muted })
  g("Ignore", { fg = c.muted })

  g("SpellBad", { undercurl = true, sp = c.red })
  g("SpellCap", { undercurl = true, sp = c.ochre })
  g("SpellLocal", { undercurl = true, sp = c.teal })
  g("SpellRare", { undercurl = true, sp = c.plum })

  g("DiffAdd", { bg = c.diff_add })
  g("DiffDelete", { bg = c.diff_del })
  g("DiffChange", { bg = c.diff_change })
  g("DiffText", { bg = c.diff_text })
  g("diffAdded", { fg = c.green })
  g("diffRemoved", { fg = c.red })
  g("diffChanged", { fg = c.indigo })
  g("diffFile", { fg = c.fg_dim, bold = true })
  g("diffLine", { fg = c.muted })
  g("diffNewFile", { fg = c.green })
  g("diffOldFile", { fg = c.red })

  g("Added", { fg = c.green })
  g("Removed", { fg = c.red })
  g("Changed", { fg = c.indigo })

  -------------------------------------------------------------------------
  -- 语法（legacy）
  -------------------------------------------------------------------------
  g("Comment", { fg = c.comment, italic = comment_italic })
  g("Constant", { fg = c.ochre })
  g("String", { fg = c.green })
  g("Character", { fg = c.green })
  g("Number", { fg = c.ochre })
  g("Boolean", { fg = c.ochre })
  g("Float", { fg = c.ochre })
  g("Identifier", { fg = c.fg })
  g("Function", { fg = c.indigo })
  g("Statement", { fg = c.red, bold = kw_bold })
  g("Conditional", { fg = c.red, bold = kw_bold })
  g("Repeat", { fg = c.red, bold = kw_bold })
  g("Label", { fg = c.red })
  g("Operator", { fg = c.muted })
  g("Keyword", { fg = c.red, bold = kw_bold })
  g("Exception", { fg = c.red, bold = kw_bold })
  g("PreProc", { fg = c.plum })
  g("Include", { fg = c.red })
  g("Define", { fg = c.plum })
  g("Macro", { fg = c.plum })
  g("PreCondit", { fg = c.plum })
  g("Type", { fg = c.teal })
  g("StorageClass", { fg = c.red })
  g("Structure", { fg = c.teal })
  g("Typedef", { fg = c.teal })
  g("Special", { fg = c.plum })
  g("SpecialChar", { fg = c.plum })
  g("SpecialComment", { fg = c.comment, italic = comment_italic })
  g("Tag", { fg = c.red })
  g("Delimiter", { fg = c.muted })
  g("Debug", { fg = c.ochre })
  g("Underlined", { underline = true, fg = c.indigo })
  g("Bold", { bold = true })
  g("Italic", { italic = true })
  g("Error", { fg = c.red, bold = true })
  g("Todo", { fg = c.bg, bg = c.ochre, bold = true })

  -------------------------------------------------------------------------
  -- Treesitter（0.9 / 0.10 / 0.11 通用命名）
  -------------------------------------------------------------------------
  g("@variable", { fg = c.fg })
  g("@variable.builtin", { fg = c.red, italic = true })
  g("@variable.parameter", { fg = c.fg_dim })
  g("@variable.member", { fg = c.fg_dim })
  g("@variable.parameter.builtin", { fg = c.plum, italic = true })

  g("@constant", { fg = c.ochre })
  g("@constant.builtin", { fg = c.ochre, italic = true })
  g("@constant.macro", { fg = c.plum })

  g("@module", { fg = c.teal })
  g("@module.builtin", { fg = c.teal, italic = true })

  g("@label", { fg = c.red })

  g("@string", { fg = c.green })
  g("@string.documentation", { fg = c.green, italic = true })
  g("@string.regexp", { fg = c.ochre })
  g("@string.escape", { fg = c.plum })
  g("@string.special", { fg = c.plum })
  g("@string.special.url", { fg = c.indigo, underline = true })
  g("@string.special.symbol", { fg = c.plum })
  g("@character", { fg = c.green })
  g("@character.special", { fg = c.plum })

  g("@number", { fg = c.ochre })
  g("@number.float", { fg = c.ochre })
  g("@boolean", { fg = c.ochre })

  g("@type", { fg = c.teal })
  g("@type.builtin", { fg = c.teal, italic = true })
  g("@type.definition", { fg = c.teal })
  g("@type.qualifier", { fg = c.red })

  g("@attribute", { fg = c.plum })
  g("@attribute.builtin", { fg = c.plum, italic = true })
  g("@property", { fg = c.fg_dim })

  g("@function", { fg = c.indigo })
  g("@function.builtin", { fg = c.indigo, italic = true })
  g("@function.call", { fg = c.indigo })
  g("@function.macro", { fg = c.plum })
  g("@function.method", { fg = c.indigo })
  g("@function.method.call", { fg = c.indigo })
  g("@constructor", { fg = c.teal })
  g("@operator", { fg = c.muted })

  g("@keyword", { fg = c.red, bold = kw_bold })
  g("@keyword.function", { fg = c.red, bold = kw_bold })
  g("@keyword.operator", { fg = c.red })
  g("@keyword.return", { fg = c.red, bold = kw_bold })
  g("@keyword.conditional", { fg = c.red, bold = kw_bold })
  g("@keyword.repeat", { fg = c.red, bold = kw_bold })
  g("@keyword.exception", { fg = c.red, bold = kw_bold })
  g("@keyword.import", { fg = c.red })
  g("@keyword.type", { fg = c.red })
  g("@keyword.modifier", { fg = c.red })
  g("@keyword.directive", { fg = c.plum })
  g("@keyword.directive.define", { fg = c.plum })

  g("@punctuation.delimiter", { fg = c.muted })
  g("@punctuation.bracket", { fg = c.muted })
  g("@punctuation.special", { fg = c.plum })

  g("@comment", { fg = c.comment, italic = comment_italic })
  g("@comment.documentation", { fg = c.comment, italic = comment_italic })
  g("@comment.error", { fg = c.red, bg = c.tint_red })
  g("@comment.warning", { fg = c.ochre, bg = c.tint_ochre })
  g("@comment.todo", { fg = c.bg, bg = c.ochre, bold = true })
  g("@comment.note", { fg = c.indigo, bg = c.tint_indigo })

  g("@markup.heading", { fg = c.red, bold = true })
  g("@markup.heading.1", { fg = c.red, bold = true })
  g("@markup.heading.2", { fg = c.ochre, bold = true })
  g("@markup.heading.3", { fg = c.indigo, bold = true })
  g("@markup.heading.4", { fg = c.teal, bold = true })
  g("@markup.heading.5", { fg = c.plum, bold = true })
  g("@markup.heading.6", { fg = c.muted, bold = true })
  g("@markup.italic", { italic = true })
  g("@markup.strong", { bold = true })
  g("@markup.strikethrough", { strikethrough = true })
  g("@markup.underline", { underline = true })
  g("@markup.link", { fg = c.indigo })
  g("@markup.link.label", { fg = c.indigo, underline = true })
  g("@markup.link.url", { fg = c.indigo, underline = true })
  g("@markup.raw", { fg = c.green })
  g("@markup.raw.block", { fg = c.green })
  g("@markup.list", { fg = c.plum })
  g("@markup.list.checked", { fg = c.green })
  g("@markup.list.unchecked", { fg = c.muted })
  g("@markup.quote", { fg = c.comment, italic = true })
  g("@markup.math", { fg = c.teal })

  g("@tag", { fg = c.red })
  g("@tag.builtin", { fg = c.red })
  g("@tag.attribute", { fg = c.ochre })
  g("@tag.delimiter", { fg = c.muted })

  g("@diff.plus", { fg = c.green })
  g("@diff.minus", { fg = c.red })
  g("@diff.delta", { fg = c.indigo })

  -- 0.8 时代的旧捕获名，留着不亏
  g("@field", { fg = c.fg_dim })
  g("@parameter", { fg = c.fg_dim })
  g("@namespace", { fg = c.teal })
  g("@method", { fg = c.indigo })
  g("@method.call", { fg = c.indigo })
  g("@text", { fg = c.fg })
  g("@text.literal", { fg = c.green })
  g("@text.reference", { fg = c.indigo })
  g("@text.title", { fg = c.red, bold = true })
  g("@text.uri", { fg = c.indigo, underline = true })
  g("@text.underline", { underline = true })
  g("@text.todo", { fg = c.bg, bg = c.ochre, bold = true })
  g("@text.note", { fg = c.indigo })
  g("@text.warning", { fg = c.ochre })
  g("@text.danger", { fg = c.red })

  -------------------------------------------------------------------------
  -- LSP / 诊断
  -------------------------------------------------------------------------
  g("DiagnosticError", { fg = c.red })
  g("DiagnosticWarn", { fg = c.ochre })
  g("DiagnosticInfo", { fg = c.indigo })
  g("DiagnosticHint", { fg = c.teal })
  g("DiagnosticOk", { fg = c.green })
  g("DiagnosticDeprecated", { fg = c.muted, strikethrough = true })
  g("DiagnosticUnnecessary", { fg = c.muted, italic = true })

  g("DiagnosticVirtualTextError", { fg = c.red, bg = c.tint_red })
  g("DiagnosticVirtualTextWarn", { fg = c.ochre, bg = c.tint_ochre })
  g("DiagnosticVirtualTextInfo", { fg = c.indigo, bg = c.tint_indigo })
  g("DiagnosticVirtualTextHint", { fg = c.teal, bg = c.tint_teal })
  g("DiagnosticVirtualTextOk", { fg = c.green, bg = c.tint_green })

  g("DiagnosticUnderlineError", { undercurl = true, sp = c.red })
  g("DiagnosticUnderlineWarn", { undercurl = true, sp = c.ochre })
  g("DiagnosticUnderlineInfo", { undercurl = true, sp = c.indigo })
  g("DiagnosticUnderlineHint", { undercurl = true, sp = c.teal })
  g("DiagnosticUnderlineOk", { undercurl = true, sp = c.green })

  g("DiagnosticSignError", { fg = c.red })
  g("DiagnosticSignWarn", { fg = c.ochre })
  g("DiagnosticSignInfo", { fg = c.indigo })
  g("DiagnosticSignHint", { fg = c.teal })
  g("DiagnosticSignOk", { fg = c.green })

  g("DiagnosticFloatingError", { fg = c.red, bg = c.bg_alt })
  g("DiagnosticFloatingWarn", { fg = c.ochre, bg = c.bg_alt })
  g("DiagnosticFloatingInfo", { fg = c.indigo, bg = c.bg_alt })
  g("DiagnosticFloatingHint", { fg = c.teal, bg = c.bg_alt })
  g("DiagnosticFloatingOk", { fg = c.green, bg = c.bg_alt })

  -- 0.11 起的新名字，写上也兼容
  g("VirtualTextError", { fg = c.red, bg = c.tint_red })
  g("VirtualTextWarn", { fg = c.ochre, bg = c.tint_ochre })
  g("VirtualTextInfo", { fg = c.indigo, bg = c.tint_indigo })
  g("VirtualTextHint", { fg = c.teal, bg = c.tint_teal })
  g("VirtualTextOk", { fg = c.green, bg = c.tint_green })
  g("VirtualTextDeprecated", { fg = c.muted, strikethrough = true })

  g("LspReferenceText", { bg = c.bg_soft })
  g("LspReferenceRead", { bg = c.bg_soft })
  g("LspReferenceWrite", { bg = c.bg_soft, underline = true })
  g("LspSignatureActiveParameter", { fg = c.red, bold = true })
  g("LspCodeLens", { fg = c.muted, italic = true })
  g("LspCodeLensSeparator", { fg = c.line })
  g("LspInlayHint", { fg = c.muted, bg = c.bg_alt, italic = true })

  g("@lsp.type.class", { link = "@type" })
  g("@lsp.type.enum", { link = "@type" })
  g("@lsp.type.enumMember", { link = "@constant" })
  g("@lsp.type.interface", { link = "@type" })
  g("@lsp.type.struct", { link = "@type" })
  g("@lsp.type.typeParameter", { link = "@type" })
  g("@lsp.type.namespace", { link = "@module" })
  g("@lsp.type.parameter", { fg = c.fg_dim })
  g("@lsp.type.property", { fg = c.fg_dim })
  g("@lsp.type.variable", { fg = c.fg })
  g("@lsp.type.function", { link = "@function" })
  g("@lsp.type.method", { link = "@function.method" })
  g("@lsp.type.keyword", { link = "@keyword" })
  g("@lsp.type.macro", { link = "@function.macro" })
  g("@lsp.typemod.variable.defaultLibrary", { link = "@variable.builtin" })
  g("@lsp.typemod.function.defaultLibrary", { link = "@function.builtin" })
  g("@lsp.typemod.variable.readonly", { fg = c.ochre })

  g("NavicText", { fg = c.fg_dim })
  g("NavicSeparator", { fg = c.muted })

  -------------------------------------------------------------------------
  -- 通用插件
  -------------------------------------------------------------------------
  -- gitsigns
  g("GitSignsAdd", { fg = c.green })
  g("GitSignsChange", { fg = c.ochre })
  g("GitSignsDelete", { fg = c.red })
  g("GitSignsTopdelete", { fg = c.red })
  g("GitSignsChangedelete", { fg = c.plum })
  -- 未跟踪：梅色，和侧栏 Explorer 里的未跟踪文件名同色（见 SnacksPickerGitStatusUntracked）
  g("GitSignsUntracked", { fg = c.plum })
  g("GitSignsAddNr", { fg = c.green })
  g("GitSignsChangeNr", { fg = c.ochre })
  g("GitSignsDeleteNr", { fg = c.red })
  g("GitSignsAddLn", { bg = c.diff_add })
  g("GitSignsChangeLn", { bg = c.diff_change })
  g("GitSignsDeleteLn", { bg = c.diff_del })
  g("GitSignsCurrentLineBlame", { fg = c.muted, italic = true })

  -- telescope
  g("TelescopeNormal", { fg = c.fg, bg = c.bg_alt })
  g("TelescopeBorder", { fg = c.line, bg = c.bg_alt })
  g("TelescopeTitle", { fg = c.red, bg = c.bg_alt, bold = true })
  g("TelescopePromptTitle", { fg = c.red, bg = c.bg_alt, bold = true })
  g("TelescopeResultsTitle", { fg = c.muted, bg = c.bg_alt })
  g("TelescopePreviewTitle", { fg = c.muted, bg = c.bg_alt })
  g("TelescopePromptNormal", { fg = c.fg, bg = c.bg_alt })
  g("TelescopePromptBorder", { fg = c.line, bg = c.bg_alt })
  g("TelescopePromptPrefix", { fg = c.red })
  g("TelescopeResultsNormal", { fg = c.fg_dim, bg = c.bg_alt })
  g("TelescopeResultsBorder", { fg = c.line, bg = c.bg_alt })
  g("TelescopePreviewNormal", { fg = c.fg_dim, bg = c.bg_alt })
  g("TelescopePreviewBorder", { fg = c.line, bg = c.bg_alt })
  g("TelescopeSelection", { fg = c.fg, bg = c.sel })
  g("TelescopeSelectionCaret", { fg = c.red, bg = c.sel })
  g("TelescopeMatching", { fg = c.red, bold = true })
  g("TelescopeMultiSelection", { fg = c.ochre })
  g("TelescopeResultsComment", { fg = c.comment })

  -- neo-tree
  g("NeoTreeNormal", { fg = c.fg_dim, bg = c.bg_alt })
  g("NeoTreeNormalNC", { fg = c.fg_dim, bg = c.bg_alt })
  g("NeoTreeWinSeparator", { fg = c.line, bg = c.bg_alt })
  g("NeoTreeEndOfBuffer", { fg = c.bg_alt, bg = c.bg_alt })
  g("NeoTreeRootName", { fg = c.red, bold = true })
  g("NeoTreeTitleBar", { fg = c.red, bg = c.bg_alt, bold = true })
  g("NeoTreeDirectoryName", { fg = c.indigo })
  g("NeoTreeDirectoryIcon", { fg = c.indigo })
  g("NeoTreeFileName", { fg = c.fg_dim })
  g("NeoTreeFileIcon", { fg = c.muted })
  g("NeoTreeFileNameOpened", { fg = c.fg })
  g("NeoTreeIndentMarker", { fg = c.line })
  g("NeoTreeExpander", { fg = c.muted })
  g("NeoTreeSymbolicLinkTarget", { fg = c.teal })
  g("NeoTreeModified", { fg = c.ochre })
  g("NeoTreeGitAdded", { fg = c.green })
  g("NeoTreeGitModified", { fg = c.ochre })
  g("NeoTreeGitDeleted", { fg = c.red })
  g("NeoTreeGitUntracked", { fg = c.plum })
  g("NeoTreeGitIgnored", { fg = c.muted })
  g("NeoTreeFloatBorder", { fg = c.line, bg = c.bg_alt })
  g("NeoTreeFloatTitle", { fg = c.red, bg = c.bg_alt, bold = true })

  -- which-key
  g("WhichKey", { fg = c.red, bold = true })
  g("WhichKeyGroup", { fg = c.indigo })
  g("WhichKeyDesc", { fg = c.fg_dim })
  g("WhichKeySeparator", { fg = c.muted })
  g("WhichKeyValue", { fg = c.muted })
  g("WhichKeyFloat", { bg = c.bg_alt })
  g("WhichKeyBorder", { fg = c.line, bg = c.bg_alt })
  g("WhichKeyTitle", { fg = c.red, bg = c.bg_alt, bold = true })
  g("WhichKeyIcon", { fg = c.muted })
  g("WhichKeyIconAzure", { fg = c.indigo })

  -- noice
  g("NoiceCmdline", { fg = c.fg, bg = c.bg_alt })
  g("NoiceCmdlineIcon", { fg = c.red })
  g("NoiceCmdlineIconSearch", { fg = c.ochre })
  g("NoiceCmdlinePopup", { fg = c.fg, bg = c.bg_alt })
  g("NoiceCmdlinePopupBorder", { fg = c.line, bg = c.bg_alt })
  g("NoiceCmdlinePopupBorderSearch", { fg = c.ochre, bg = c.bg_alt })
  g("NoiceCmdlinePrompt", { fg = c.red, bold = true })
  g("NoiceConfirm", { fg = c.fg, bg = c.bg_alt })
  g("NoiceConfirmBorder", { fg = c.line, bg = c.bg_alt })
  g("NoiceMini", { fg = c.fg_dim, bg = c.bg_alt })
  g("NoiceLspProgressTitle", { fg = c.muted })
  g("NoiceLspProgressClient", { fg = c.indigo })
  g("NoiceLspProgressSpinner", { fg = c.red })
  g("NoiceFormatProgressDone", { fg = c.bg, bg = c.red })
  g("NoiceFormatProgressTodo", { fg = c.muted, bg = c.bg_soft })

  -- notify
  g("NotifyBackground", { bg = c.bg_alt })
  g("NotifyERRORBorder", { fg = c.red, bg = c.bg_alt })
  g("NotifyERRORIcon", { fg = c.red, bg = c.bg_alt })
  g("NotifyERRORTitle", { fg = c.red, bg = c.bg_alt, bold = true })
  g("NotifyWARNBorder", { fg = c.ochre, bg = c.bg_alt })
  g("NotifyWARNIcon", { fg = c.ochre, bg = c.bg_alt })
  g("NotifyWARNTitle", { fg = c.ochre, bg = c.bg_alt, bold = true })
  g("NotifyINFOBorder", { fg = c.indigo, bg = c.bg_alt })
  g("NotifyINFOIcon", { fg = c.indigo, bg = c.bg_alt })
  g("NotifyINFOTitle", { fg = c.indigo, bg = c.bg_alt, bold = true })
  g("NotifyDEBUGBorder", { fg = c.muted, bg = c.bg_alt })
  g("NotifyDEBUGIcon", { fg = c.muted, bg = c.bg_alt })
  g("NotifyDEBUGTitle", { fg = c.muted, bg = c.bg_alt })
  g("NotifyTRACEBorder", { fg = c.muted, bg = c.bg_alt })
  g("NotifyTRACEIcon", { fg = c.muted, bg = c.bg_alt })
  g("NotifyTRACETitle", { fg = c.muted, bg = c.bg_alt })

  -- trouble
  g("TroubleNormal", { fg = c.fg_dim, bg = c.bg_alt })
  g("TroubleNormalNC", { fg = c.fg_dim, bg = c.bg_alt })
  g("TroubleText", { fg = c.fg_dim })
  g("TroubleCount", { fg = c.red, bg = c.bg_soft })
  g("TroubleFile", { fg = c.muted })
  g("TroubleSource", { fg = c.teal })
  g("TroubleCode", { fg = c.muted })
  g("TroubleLocation", { fg = c.muted })
  g("TroubleFoldIcon", { fg = c.muted })
  g("TroubleIndent", { fg = c.line })
  g("TroublePos", { fg = c.muted })
  g("TroubleIconError", { fg = c.red })
  g("TroubleIconWarn", { fg = c.ochre })
  g("TroubleIconInfo", { fg = c.indigo })
  g("TroubleIconHint", { fg = c.teal })

  -- bufferline
  g("BufferLineFill", { bg = c.bg_alt })
  g("BufferLineBackground", { fg = c.muted, bg = c.bg_alt })
  g("BufferLineBuffer", { fg = c.muted, bg = c.bg_alt })
  g("BufferLineBufferSelected", { fg = c.fg, bg = c.bg, bold = true })
  g("BufferLineBufferVisible", { fg = c.fg_dim, bg = c.bg_alt })
  g("BufferLineIndicatorSelected", { fg = c.red, bg = c.bg })
  g("BufferLineSeparator", { fg = c.line, bg = c.bg_alt })
  g("BufferLineSeparatorSelected", { fg = c.line, bg = c.bg })
  g("BufferLineCloseButton", { fg = c.muted, bg = c.bg_alt })
  g("BufferLineCloseButtonSelected", { fg = c.red, bg = c.bg })
  g("BufferLineModified", { fg = c.ochre, bg = c.bg_alt })
  g("BufferLineModifiedSelected", { fg = c.ochre, bg = c.bg })

  -- snacks（LazyVim 的 dashboard / picker / notifier / indent）
  g("SnacksDashboardHeader", { fg = c.red })
  g("SnacksDashboardIcon", { fg = c.muted })
  g("SnacksDashboardDesc", { fg = c.fg_dim })
  g("SnacksDashboardFile", { fg = c.fg_dim })
  g("SnacksDashboardDir", { fg = c.muted })
  g("SnacksDashboardFooter", { fg = c.muted, italic = true })
  g("SnacksDashboardKey", { fg = c.indigo })
  g("SnacksDashboardTitle", { fg = c.red, bold = true })
  g("SnacksDashboardTerminal", { fg = c.fg_dim })
  g("SnacksDashboardSpecial", { fg = c.plum })
  g("SnacksPicker", { fg = c.fg_dim, bg = c.bg_alt })
  g("SnacksPickerBorder", { fg = c.line, bg = c.bg_alt })
  g("SnacksPickerTitle", { fg = c.red, bg = c.bg_alt, bold = true })
  g("SnacksPickerBoxTitle", { fg = c.red, bg = c.bg_alt, bold = true })
  g("SnacksPickerSelected", { fg = c.fg, bg = c.sel })
  g("SnacksPickerMatch", { fg = c.red, bold = true })
  g("SnacksPickerDir", { fg = c.muted })
  g("SnacksPickerFile", { fg = c.fg_dim })
  g("SnacksPickerIcon", { fg = c.muted })
  -- Explorer / picker 里的文件名分档（snacks 默认把 hidden / ignored / untracked
  -- 全链到 NonText，本主题里 NonText 是极暗的分隔线色，侧栏上几乎和底色融在一起）：
  -- 普通文件 fg_dim / 目录名 indigo（SnacksPickerDirectory → Directory）/ 隐藏 faint+斜体 /
  -- ignored 最暗 / 未跟踪梅色。
  -- 隐藏文件用 faint + 斜体：读得清，又能和普通文件（fg_dim，正体）一眼区分。
  g("SnacksPickerPathHidden", { fg = c.faint, italic = true })
  -- gitignore 的文件（.git / node_modules …）是噪音，保持最暗的一档
  g("SnacksPickerPathIgnored", { fg = c.comment })
  -- 未跟踪文件名：snacks 默认链到 NonText（本主题里是极暗的分隔线色），
  -- 侧栏上基本看不见。用梅色标出来，和已暂存（teal）/ 已修改（ochre）/ 已删除（red）区分。
  g("SnacksPickerGitStatusUntracked", { fg = c.plum })
  g("SnacksPickerGitStatusIgnored", { fg = c.comment })
  g("SnacksPickerPath", { fg = c.fg_dim })
  g("SnacksPickerListCursorLine", { bg = c.sel })
  g("SnacksPickerPreviewCursorLine", { bg = c.sel })
  g("SnacksIndent", { fg = c.line })
  g("SnacksIndentScope", { fg = c.muted })
  g("SnacksIndentChunk", { fg = c.bg_soft })
  g("SnacksNotifierError", { fg = c.red, bg = c.bg_alt })
  g("SnacksNotifierWarn", { fg = c.ochre, bg = c.bg_alt })
  g("SnacksNotifierInfo", { fg = c.indigo, bg = c.bg_alt })
  g("SnacksNotifierDebug", { fg = c.muted, bg = c.bg_alt })
  g("SnacksNotifierTrace", { fg = c.muted, bg = c.bg_alt })
  g("SnacksNotifierBorderError", { fg = c.red, bg = c.bg_alt })
  g("SnacksNotifierBorderWarn", { fg = c.ochre, bg = c.bg_alt })
  g("SnacksNotifierBorderInfo", { fg = c.indigo, bg = c.bg_alt })
  g("SnacksNotifierBorderDebug", { fg = c.line, bg = c.bg_alt })
  g("SnacksNotifierBorderTrace", { fg = c.line, bg = c.bg_alt })
  g("SnacksNotifierTitleError", { fg = c.red, bold = true })
  g("SnacksNotifierTitleWarn", { fg = c.ochre, bold = true })
  g("SnacksNotifierTitleInfo", { fg = c.indigo, bold = true })
  g("SnacksNotifierTitleDebug", { fg = c.muted, bold = true })
  g("SnacksNotifierTitleTrace", { fg = c.muted, bold = true })

  -- lazy.nvim
  g("LazyNormal", { fg = c.fg_dim, bg = c.bg_alt })
  g("LazyButton", { fg = c.fg_dim, bg = c.bg_soft })
  g("LazyButtonActive", { fg = c.bg, bg = c.red, bold = true })
  g("LazyH1", { fg = c.bg, bg = c.red, bold = true })
  g("LazyH2", { fg = c.fg, bold = true })
  g("LazySpecial", { fg = c.teal })
  g("LazyProgressDone", { fg = c.red })
  g("LazyProgressTodo", { fg = c.line })
  g("LazyCommit", { fg = c.ochre })
  g("LazyDimmed", { fg = c.muted })
  g("LazyDir", { fg = c.indigo })
  g("LazyUrl", { fg = c.indigo })
  g("LazyReasonPlugin", { fg = c.plum })
  g("LazyReasonEvent", { fg = c.ochre })
  g("LazyReasonCmd", { fg = c.teal })
  g("LazyReasonFt", { fg = c.indigo })

  -- mason
  g("MasonNormal", { fg = c.fg_dim, bg = c.bg_alt })
  g("MasonHeader", { fg = c.bg, bg = c.red, bold = true })
  g("MasonHeaderSecondary", { fg = c.bg, bg = c.bg_soft })
  g("MasonHighlight", { fg = c.indigo })
  g("MasonHighlightBlock", { fg = c.fg, bg = c.bg_soft })
  g("MasonHighlightBlockBold", { fg = c.bg, bg = c.red, bold = true })
  g("MasonMuted", { fg = c.muted })
  g("MasonMutedBlock", { fg = c.muted, bg = c.bg_soft })
  g("MasonError", { fg = c.red })
  g("MasonWarning", { fg = c.ochre })
  g("MasonHeading", { fg = c.fg, bold = true })

  -- illuminate / indent-blankline / flash / mini
  g("IlluminatedWordText", { bg = c.bg_soft })
  g("IlluminatedWordRead", { bg = c.bg_soft })
  g("IlluminatedWordWrite", { bg = c.bg_soft })
  g("IblIndent", { fg = c.line })
  g("IblScope", { fg = c.muted })
  g("FlashLabel", { fg = c.bg, bg = c.red, bold = true })
  g("FlashMatch", { bg = c.sel })
  g("FlashCurrent", { bg = c.bg_soft })
  g("FlashPrompt", { fg = c.fg_dim, bg = c.bg_alt })
  g("FlashPromptIcon", { fg = c.red })
  g("MiniCursorword", { underline = true })
  g("MiniCursorwordCurrent", { underline = true })
  g("MiniIndentscopeSymbol", { fg = c.muted })
  g("MiniStatuslineModeNormal", { fg = c.bg, bg = c.red, bold = true })
  g("MiniStatuslineModeInsert", { fg = c.bg, bg = c.green, bold = true })
  g("MiniStatuslineModeVisual", { fg = c.bg, bg = c.indigo, bold = true })
  g("MiniStatuslineModeReplace", { fg = c.bg, bg = c.ochre, bold = true })
  g("MiniStatuslineModeCommand", { fg = c.bg, bg = c.plum, bold = true })
  g("MiniStatuslineFilename", { fg = c.fg_dim, bg = c.bg_alt })
  g("MiniStatuslineDevinfo", { fg = c.muted, bg = c.bg_alt })

  -- blink.cmp / nvim-cmp（LazyVim 新老版本都照顾一下）
  g("BlinkCmpMenu", { fg = c.fg_dim, bg = c.bg_alt })
  g("BlinkCmpMenuBorder", { fg = c.line, bg = c.bg_alt })
  g("BlinkCmpMenuSelection", { fg = c.fg, bg = c.pmenu_sel, bold = true })
  g("BlinkCmpLabel", { fg = c.fg_dim })
  g("BlinkCmpLabelMatch", { fg = c.red, bold = true })
  g("BlinkCmpLabelDeprecated", { fg = c.muted, strikethrough = true })
  g("BlinkCmpLabelDetail", { fg = c.muted })
  g("BlinkCmpLabelDescription", { fg = c.muted })
  g("BlinkCmpKind", { fg = c.indigo })
  g("BlinkCmpDoc", { fg = c.fg_dim, bg = c.bg_alt })
  g("BlinkCmpDocBorder", { fg = c.line, bg = c.bg_alt })
  g("BlinkCmpSignatureHelp", { fg = c.fg_dim, bg = c.bg_alt })
  g("BlinkCmpSignatureHelpBorder", { fg = c.line, bg = c.bg_alt })
  g("BlinkCmpSignatureHelpActiveParameter", { fg = c.red, bold = true })
  g("BlinkCmpGhostText", { fg = c.muted, italic = true })
  g("BlinkCmpScrollBarThumb", { bg = c.line })
  g("BlinkCmpScrollBarGutter", { bg = c.bg_soft })

  g("CmpNormal", { fg = c.fg_dim, bg = c.bg_alt })
  g("CmpBorder", { fg = c.line, bg = c.bg_alt })
  g("CmpItemAbbr", { fg = c.fg_dim })
  g("CmpItemAbbrMatch", { fg = c.red, bold = true })
  g("CmpItemAbbrDeprecated", { fg = c.muted, strikethrough = true })
  g("CmpItemKind", { fg = c.indigo })
  g("CmpItemMenu", { fg = c.muted })

  -- 杂项
  g("healthError", { fg = c.red })
  g("healthWarning", { fg = c.ochre })
  g("healthSuccess", { fg = c.green })
  g("qfline", { fg = c.muted })
  g("TodoFgFIX", { fg = c.red })
  g("TodoFgTODO", { fg = c.ochre })
  g("TodoFgHACK", { fg = c.plum })
  g("TodoFgNOTE", { fg = c.indigo })
  g("TodoFgWARN", { fg = c.ochre })
  g("TodoBgFIX", { fg = c.bg, bg = c.red, bold = true })
  g("TodoBgTODO", { fg = c.bg, bg = c.ochre, bold = true })
  g("TodoBgNOTE", { fg = c.bg, bg = c.indigo, bold = true })
  g("TodoBgWARN", { fg = c.bg, bg = c.ochre, bold = true })
  g("TodoBgHACK", { fg = c.bg, bg = c.plum, bold = true })

  return H
end

---------------------------------------------------------------------------
-- load
---------------------------------------------------------------------------

local function apply_terminal(c)
  for i = 0, 15 do
    vim.g["terminal_color_" .. i] = c.term[i + 1]
  end
end

function M.load(style)
  if not STYLES[style] then
    style = "paper"
  end
  local o = M.config
  local c = resolve(style)

  vim.o.termguicolors = true

  -- 先摘掉 colors_name，避免改 background 时触发自身重载
  vim.g.colors_name = nil
  vim.o.background = c.background

  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  vim.g.colors_name = c.name

  local H = make_groups(c, o)
  if o.on_highlights then
    local ok, err = pcall(o.on_highlights, H, c)
    if not ok and vim.notify then
      vim.notify("takeboat: on_highlights 出错 — " .. tostring(err), vim.log.levels.WARN)
    end
  end

  for name, spec in pairs(H) do
    api.nvim_set_hl(0, name, spec)
  end

  apply_terminal(c)
  M.colors = c
end

function M.setup(opts)
  opts = opts or {}
  for k, v in pairs(opts) do
    if k ~= "style" then
      M.config[k] = v
    end
  end
  return M
end

return M
