# 第 8 章 — 模組、cabal 專案解剖、開發工作流

## 模組

```haskell
module Examples.Adventure    -- 模組名 = 路徑:src/Examples/Adventure.hs
  ( Element (..)             -- 匯出型別與全部建構子
  , Player (..)
  , takeDamage               -- 匯出函式
  ) where                    -- 沒列出來的就是私有 —— 這是你的封裝工具
```

import 的四種常見形態(GHC2024 允許 `qualified` 後置):

```haskell
import Data.Text (Text)                  -- 只拿指定名字
import Data.Text qualified as T          -- 全部拿,但要掛前綴
import Data.Map.Strict qualified as Map
import Examples.Adventure                -- 全拿(小心名字衝突,少用)
```

## 解剖 level01-foundations.cabal

```
common settings                  -- 共用設定,各元件 import 進去
  default-language: GHC2024     -- 2026 的語言基準
  ghc-options: -Wall -Wcompat ...
  build-depends: base, text, containers

library                          -- 可被別人 import 的模組
  hs-source-dirs: src exercises
  exposed-modules: ...

executable wordcount             -- 會編出 .exe 的進入點
  main-is: Main.hs
  build-depends: level01-foundations   -- 依賴上面的 library

test-suite level01-tests         -- cabal test 跑的東西
```

一個套件 = 一個 `.cabal` 檔 = library + 任意個 executable/test-suite。
根目錄的 `cabal.project` 把多個套件收進同一個工作區(HLS 也是讀它)。

## 常用指令複習

```powershell
cabal build all            # 建置
cabal repl <套件名>        # ghci 載入套件(改檔案後 :r 重載)
cabal test <套件名>        # 跑測試
cabal run wordcount -- 引數
cabal test level01-foundations -f solutions   # 用參考解答跑(驗證測試)
```

## 警告即負債

本課程開著 `-Wall -Wcompat -Wincomplete-uni-patterns -Wincomplete-record-updates`。
**把 warning 當 error 看待**:漏掉的 pattern、沒用到的變數,都是未來的 bug。
你的習題檔一開始滿是 unused-matches 警告 —— 實作完就會消失,順便當進度條。

## 每日工作流(2026 標準)

1. VS Code + HLS:存檔即時看到型別錯誤,hover 看型別,`F12` 跳定義。
2. `cabal repl` 開著,小函式先在 ghci 驗證再寫進檔案。
3. `fourmolu` 格式化、`hlint` 給重構建議(裝法見 `00-setup/`)。
4. 測試驗收:`cabal test`。

## Level 1 結業檢查

- [ ] `cabal test level01-foundations` 58 個測試全綠
- [ ] 能解釋:為什麼用 `Text` 不用 `String`?`foldl'` 和 `foldl` 差在哪?
- [ ] 能解釋:`NoFieldSelectors` + 點語法解決了什麼歷史問題?
- [ ] 能不查資料寫出:一個 sum type + 對它 total 的 pattern matching

全部打勾 → 前進 `02-intermediate/`(Functor/Applicative/Monad、
惰性求值深入、錯誤處理、測試、並行)。
