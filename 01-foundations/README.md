# Level 1 — 初級

從零開始,到能寫出「純核心 + IO 殼」的完整小程式。

## 章節

| 章 | 教材 | 習題 |
|----|------|------|
| 1 運算式與型別 | `notes/01-first-steps.md` | `E01Basics.hs` |
| 2 函式與 pattern matching | `notes/02-functions.md` | `E02Functions.hs` |
| 3 List 與遞迴 | `notes/03-lists-and-recursion.md` | `E03Lists.hs` |
| 4 ADT 與現代 record | `notes/04-adts-and-records.md` | `E04Adts.hs` |
| 5 Typeclass 與 Monoid | `notes/05-typeclasses.md` | `E05Classes.hs` |
| 6 Text | `notes/06-text.md` | `E06Text.hs` |
| 7 IO | `notes/07-io.md` | `E07IO.hs` |
| 8 模組與 cabal | `notes/08-modules-and-cabal.md` | (結業檢查) |

## 使用方式

```powershell
cabal repl level01-foundations    # 開 ghci 跟著教材實驗
cabal test level01-foundations    # 驗收習題(58 個測試全綠 = 通關)
cabal run wordcount -- notes/01-first-steps.md   # 第 7 章的範例程式
```

習題在 `exercises/`,把 `undefined` 換成實作。
卡住先重讀該章教材,真的卡死再看 `answers/`。

範例程式在 `src/`(`Examples.Adventure`、`Examples.WordCount`),
教材會指引你在 ghci 裡把玩它們。
