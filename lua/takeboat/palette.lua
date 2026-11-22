-- takeboat palette
-- 取自 takeboat 博客：纸 #f1eee6 / 墨 #14130e / 朱印 #a3382a
-- 三套：paper（纸）、night（夜）、dawn（黎明 —— 夜里把底色提亮一档，不那么压）。
-- 颜色值均为 6 位十六进制，便于直接喂给 nvim_set_hl。

local M = {}

M.paper = {
  bg      = "#f2efe7",
  bg_alt  = "#eae6da",
  bg_soft = "#e1dccb",
  fg      = "#14130e",
  fg_dim  = "#3f3d33",
  muted   = "#6f6a5d",
  comment = "#847f71",
  line    = "#d7d1c0",
  sel     = "#ded7c5",

  red     = "#a3382a",
  indigo  = "#2f4a6b",
  green   = "#4a5c3a",
  ochre   = "#8a5a24",
  plum    = "#6d3f52",
  teal    = "#2c5a58",
}

M.night = {
  bg      = "#0c0c0b",
  bg_alt  = "#141413",
  bg_soft = "#1c1c18",
  fg      = "#e9e5da",
  fg_dim  = "#c9c4b7",
  muted   = "#8a8578",
  comment = "#7d7a6d",
  line    = "#2b2b25",
  sel     = "#24241f",

  red     = "#d2604a",
  indigo  = "#8fb2dc",
  green   = "#a6c07e",
  ochre   = "#dcae6a",
  plum    = "#c38fa5",
  teal    = "#7fbcb4",
}

-- dawn：和 night 同一套颜料，只把底色整体提亮两档（#0c0c0b -> #1b1a16），
-- 长时间盯屏不至于像掉进墨缸里；对比度仍按深色主题算（background=dark）。
M.dawn = {
  bg      = "#1b1a16",
  bg_alt  = "#24221d",
  bg_soft = "#2d2b25",
  fg      = "#e6e1d4",
  fg_dim  = "#c6c1b3",
  muted   = "#8a8578",
  comment = "#7d7a6d",
  line    = "#35322b",
  sel     = "#2f2c26",

  red     = "#d2604a",
  indigo  = "#8fb2dc",
  green   = "#a6c07e",
  ochre   = "#dcae6a",
  plum    = "#c38fa5",
  teal    = "#7fbcb4",
}

return M
