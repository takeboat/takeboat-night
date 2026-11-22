# takeboat.nvim

纸 `#f2efe7`、墨 `#14130e`、朱印 `#a3382a` 抽出来的一套配色，三个版本。

| `:colorscheme` | 背景 | 说明 |
| --- | --- | --- |
| `takeboat` | 纸（light） | 暖白纸面 + 墨字 + 朱砂强调 |
| `takeboat-night` | 夜（dark） | `#0c0c0b` 墨底与米白字 |
| `takeboat-dawn` | 黎明（dark） | 与 night 同色相，底色提一档到 `#1b1a16` |

## 颜色

| 语义 | 纸 | 夜 | 黎明 | 用在哪 |
| --- | --- | --- | --- | --- |
| 底 | `#f2efe7` | `#0c0c0b` | `#1b1a16` | Normal |
| 浮层 | `#eae6da` | `#141413` | `#24221d` | 侧栏 / 浮窗 / Pmenu |
| 正文 | `#14130e` | `#e9e5da` | `#e6e1d4` | 普通文本 |
| 次要文字 | `#3f3d33` | `#c9c4b7` | `#c6c1b3` | 参数 / 成员 / 状态栏 |
| 注释 | `#847f71` | `#7d7a6d` | `#7d7a6d` | Comment |
| 朱印 | `#a3382a` | `#d2604a` | 同夜 | 关键字 / 光标行 / 强调 |
| 花青 | `#2f4a6b` | `#8fb2dc` | 同夜 | 函数 / 链接 / 信息 |
| 石绿 | `#4a5c3a` | `#a6c07e` | 同夜 | 字符串 / 新增 |
| 赭石 | `#8a5a24` | `#dcae6a` | 同夜 | 数字 / 常量 / 警告 |
| 紫绛 | `#6d3f52` | `#c38fa5` | 同夜 | 预处理 / 转义 / 未跟踪 |
| 青碧 | `#2c5a58` | `#7fbcb4` | 同夜 | 类型 / 提示 |

## LazyVim / lazy.nvim

`lua/plugins/takeboat.lua`：

```lua
return {
  {
    "takeboat/takeboat-night",
    name = "takeboat",
    priority = 1000,
    lazy = false,
    opts = {
      italic_comments = false,
      transparent = false,
    },
    config = function(_, opts)
      require("takeboat").setup(opts)
      vim.cmd.colorscheme("takeboat-night") -- 纸：takeboat　黎明：takeboat-dawn
    end,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "takeboat-night" } },
}
```

`priority = 1000` + `lazy = false` 不能省，否则 LazyVim 启动早期执行 `opts.colorscheme` 会报 `colorscheme not found`。
