# takeboat.nvim

从 takeboat 博客里抽出来的一套配色：**纸 `#f2efe7`、墨 `#14130e`、朱印 `#a3382a`**。
三个版本：偏白昼的纸、偏深夜的墨，以及把墨底提亮一档的黎明。

| 名字 | 背景 | 说明 |
| --- | --- | --- |
| `takeboat` | 纸（light） | 博客本体的观感，暖白纸面 + 墨字 + 朱砂强调 |
| `takeboat-night` | 夜（dark） | 同一套语义，换成 #0c0c0b 墨底与米白字 |
| `takeboat-dawn` | 黎明（dark） | 与 night 同色相，只把底色提一档到 #1b1a16，长时间盯屏不压眼 |

不依赖任何插件，LazyVim 与裸 nvim 都能直接用；同时附带 lualine 主题（`theme = "auto"` 自动生效）。

---

## 一、安装

仓库结构就是一个标准 colorscheme 插件，`colors/` 提供 `:colorscheme` 入口，
`lua/takeboat/` 是主体，`lua/lualine/themes/` 是状态栏主题。

### 1. lazy.nvim / LazyVim（推荐）

`lua/plugins/takeboat.lua`（完整可抄的版本见 [`examples/lazyvim.lua`](./examples/lazyvim.lua)）：

```lua
return {
  {
    "takeboat/takeboat-night",
    name = "takeboat",
    priority = 1000,
    lazy = false,
    opts = { italic_comments = true },
    config = function(_, opts)
      require("takeboat").setup(opts)
      vim.cmd.colorscheme("takeboat-night") -- 纸：takeboat　黎明：takeboat-dawn
    end,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "takeboat-night" } },
}
```

`priority = 1000` + `lazy = false` 不能省：LazyVim 启动早期就会执行 `opts.colorscheme`，
插件还没加载完会报 `colorscheme not found`。LazyVim 用户改第二段里的 `colorscheme` 即可，
不必再写 `opts.colorscheme`（两处要一致）。

### 2. 裸 nvim + lazy.nvim

同上，去掉 `LazyVim/LazyVim` 那段；没有 lazy.nvim 时用任意插件管理器，或直接：

```bash
git clone https://github.com/takeboat/takeboat-night ~/.local/share/nvim/site/pack/themes/start/takeboat-night
```

```lua
-- init.lua
vim.opt.termguicolors = true
require("takeboat").setup({ italic_comments = true })
vim.cmd.colorscheme("takeboat-night")
```

### 3. 拷目录（不联网的懒人法）

```bash
git clone https://github.com/takeboat/takeboat-night ~/.config/nvim/takeboat-night
```

然后 spec 里用 `dir` 指向它，而不是仓库名：

```lua
{ dir = vim.fn.stdpath("config") .. "/takeboat-night", name = "takeboat", priority = 1000, lazy = false,
  config = function() require("takeboat").setup({}); vim.cmd.colorscheme("takeboat-night") end },
```

> nvim 启动时要读 colorscheme，别把 `dir` 指向 `/mnt/c/...` 这类跨盘慢路径（WSL）。

---

## 二、切换

```vim
:colorscheme takeboat         " 纸
:colorscheme takeboat-night   " 夜
:colorscheme takeboat-dawn    " 黎明（夜的底色提亮一档）
```

或者：

```lua
require("takeboat").load("night")  -- "paper" | "night" | "dawn"
```

`takeboat` 会强制 `background=light`；`takeboat-night` 与 `takeboat-dawn` 会强制 `background=dark`
（两者只是底色不同，派生色与终端配色共用一个「夜」档），
其他插件（lualine、snacks、telescope…）据此自行适配。

---

## 三、自定义

```lua
require("takeboat").setup({
  transparent = false,      -- true：Normal/行号列透明，浮窗仍留底色
  italic_comments = true,   -- 注释斜体
  bold_keywords = false,    -- 关键字加粗
  dim_inactive = false,     -- 非当前窗口正文降到 muted（底色始终不变，见“八、注意”）
  on_highlights = function(hl, c)
    -- hl 是即将写入的高亮表，c 是解析后的调色板（含派生色 faint / tint_* / diff_*）
    hl.Comment = { fg = c.muted, italic = true }
    hl.CursorLineNr = { fg = c.red, bold = true }
  end,
})
```

想取色自己用：

```lua
local c = require("takeboat").colors   -- load 之后才有
print(c.red, c.bg, c.indigo, c.faint)
```

原始色板：`require("takeboat.palette").paper` / `.night` / `.dawn`。

---

## 四、配色

| 语义 | 纸 | 夜 | 黎明 | 用在哪 |
| --- | --- | --- | --- | --- |
| 底 | `#f2efe7` | `#0c0c0b` | `#1b1a16` | Normal |
| 浮层 | `#eae6da` | `#141413` | `#24221d` | 侧栏 / 浮窗 / Pmenu |
| 正文 | `#14130e` | `#e9e5da` | `#e6e1d4` | 普通文本 |
| 注释 | `#847f71` | `#7d7a6d` | `#7d7a6d` | Comment（斜体） |
| 朱印 | `#a3382a` | `#d2604a` | 同夜 | 关键字 / 光标行 / 强调 |
| 花青 | `#2f4a6b` | `#8fb2dc` | 同夜 | 函数 / 链接 / 信息 |
| 石绿 | `#4a5c3a` | `#a6c07e` | 同夜 | 字符串 / 新增 |
| 赭石 | `#8a5a24` | `#dcae6a` | 同夜 | 数字 / 常量 / 警告 |
| 紫绛 | `#6d3f52` | `#c38fa5` | 同夜 | 预处理 / 转义 / 特殊 / 未跟踪 |
| 青碧 | `#2c5a58` | `#7fbcb4` | 同夜 | 类型 / 提示 |

四种颜料都压得很低饱和——墨色为主，颜色只做区分，不抢戏。
`dawn` 只动底色与正文色，颜料与 `night` 完全一致：想再亮/再暗，改
`lua/takeboat/palette.lua` 里 `M.dawn` 的 `bg` / `bg_alt` / `bg_soft` 即可。

---

## 五、文件树 / picker 的文件状态分档

snacks（LazyVim 默认的 explorer 与 picker）会把 hidden / ignored / untracked 文件名
一律链到 `NonText`。本主题的 `NonText` 是极暗的分隔线色，侧栏上几乎和底色融在一起，
所以这里单独分档（以夜为例）：

| 状态 | 高亮组 | 颜色 | 对比度 vs 浮层底 `#141413` |
| --- | --- | --- | --- |
| 普通文件 | `SnacksPickerFile` | `#c9c4b7` | 10.6 |
| 目录名 | `SnacksPickerDirectory` → `Directory` | `#8fb2dc` | — |
| 隐藏文件（`.git`、`.config`） | `SnacksPickerPathHidden` | `#aaa598` + 斜体 | 7.5 |
| gitignore（`node_modules` 等噪音） | `SnacksPickerPathIgnored` | `#7d7a6d` | 4.3 |
| 未跟踪（未提交的新文件） | `SnacksPickerGitStatusUntracked` | `#c38fa5` | 6.8 |
| 已修改 / 已暂存 / 已删除 | `SnacksPickerGitStatus{Modified,Staged,Deleted}` | 赭 / 青 / 朱 | — |

`faint` 这一档（`c.faint`，muted 与 fg_dim 的中间值）就是为「次要但仍需读清」准备的；
隐藏文件用色 + 斜体双重区分，正体的普通文件名一眼就能分开。
`GitSignsUntracked` 与未跟踪文件名同色，状态列的 `?` 不会在暗底上消失。

---

## 六、覆盖了哪些组

- 编辑器：Normal/Float/Cursor/LineNr/SignColumn/StatusLine/TabLine/Pmenu/Search/Visual/Diff/Spell…
- 语法：legacy `Comment`…`Todo` 全套
- Treesitter：`@variable` `@function` `@keyword` `@type` `@string` `@markup.*` `@lsp.type.*`…
- 诊断：`Diagnostic*` 与 0.11 的 `VirtualText*` 双份
- 插件：telescope / neo-tree / which-key / noice / nvim-notify / trouble / bufferline /
  gitsigns / snacks（dashboard·picker·notifier·indent）/ lazy / mason / illuminate /
  indent-blankline / flash / mini.statusline / blink.cmp 与 nvim-cmp
- 终端 16 色

---

## 七、自检

```vim
:lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "Normal" })))
:lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "@keyword" })))
:hi CursorLineNr
```

想确认 lualine 吃到主题了：

```vim
:lua print(vim.inspect(require("lualine.themes.takeboat-night").normal.a))
```

---

## 八、注意

- 需要 `termguicolors`（插件里已自动打开，终端本身要支持 truecolor）。
- **非当前窗口（`NormalNC`）不换底色**：底色永远和 `Normal` 一致，`dim_inactive = true` 时
  只把正文降到 `muted`。因为深色档里浮层色 `bg_alt` 比 `Normal` 更亮，把它当作 `NormalNC`
  的底，焦点一移开整块编辑区就会「亮一下」，看着像闪屏——这个坑已经内置修掉了，
  不用再在 `on_highlights` 里覆盖。
- 纸色主题会把 `background` 切成 `light`，如果你的状态栏/终端背景是深色，第一次切可能有点晃眼——这是预期内的。
- 没做 `lightline`/`airline` 主题；它们不吃 `lualine` 那套文件。
