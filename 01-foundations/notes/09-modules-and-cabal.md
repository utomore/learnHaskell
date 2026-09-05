# 第 9 章 — 模組、cabal 專案解剖、開發工作流

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

### 匯出清單是你唯一的封裝工具

Haskell 沒有 `private` 關鍵字,**匯出清單就是存取控制**。`Element (..)` 匯出建構子,
外面可以 pattern match 也可以自己建;寫成 `Element`(不加 `(..)`)就只匯出型別名,
外面只能透過你提供的函式操作 —— 這叫 **smart constructor** 模式,
第 3 級 phantom types 章的 `validateName` 靠的就是它:
建構子藏起來,唯一能做出「驗證過的名字」的路徑是通過驗證函式。

`qualified` 後置寫法(`import Data.Text qualified as T`)是 `ImportQualifiedPost` 擴充,
GHC 8.10 加入、GHC2021 起預設。舊寫法 `import qualified Data.Text as T`
在舊程式碼裡到處都是,兩種等價;後置的好處只是 import 區塊排版時模組名對齊。

## 解剖 level01-foundations.cabal

```
common settings                  -- 共用設定,各元件 import 進去
  default-language: GHC2024     -- 2026 的語言基準
  default-extensions: OverloadedStrings
                      NoFieldSelectors
                      OverloadedRecordDot
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

### `default-language` 與 `default-extensions`

`GHC2024` 是一組**語言擴充的集合**:GHC 累積了三十年的擴充,
每隔幾年把「社群已公認該預設開」的那批打包成一個語言版本
(`Haskell2010` → `GHC2021` → `GHC2024`)。第 4 章的 `\case`、第 5 章的 `deriving stock`、
`import ... qualified` 後置,都是 GHC2024 內含的。

還沒進語言版本、但本專案全域開啟的三個,各有原因:

| 擴充 | 為什麼全域開 | 沒開會怎樣 |
|------|------|------|
| `OverloadedStrings` | 字串字面值能當 `Text`(第 6 章) | 每個 `Text` 字面值都要 `T.pack` |
| `OverloadedRecordDot` | `p.hp` 點語法(第 4 章) | 只能用 Haskell 98 的 `hp p` |
| `NoFieldSelectors` | 不生成頂層 selector,欄位名可重複(第 4 章) | 兩個型別不能都有 `name` 欄位 |

它們沒進 GHC2024 是因為會**改變既有程式的行為**(字面值型別變了、selector 消失了),
語言版本只收「純新增、不破壞」的擴充。所以每個專案要自己在 cabal 裡宣告 —— 這也是好事:
打開 `.cabal` 檔就知道這個專案的語言配置。

### 為什麼是 cabal 不是 Stack

你在網路上會看到大量 `stack build`、`stack.yaml`。來龍去脈:

- **2015 以前**:cabal 把所有套件裝進一個全域資料庫,兩個專案要不同版本的同一個套件就打架,
  俗稱 cabal hell。當時的 cabal 沒有 lock file、沒有工具鏈管理。
- **2015,Stack 出現**:FP Complete 推出 Stack 解決這個問題 —— 每個專案綁一個 Stackage
  snapshot(一組互相相容的套件版本)、自動裝 GHC、建置隔離。它立刻成為初學者的預設,
  幾年內大部分教學都改用 Stack。
- **2016–2019,cabal 追上**:cabal 1.24 推出 nix-style build(`cabal new-build`),
  每個套件版本各自快取、專案之間不互相干擾;cabal 3.0(2019)把它變成預設,
  `cabal.project` 的 `index-state` 提供可重現建置。Stack 當初解決的問題,cabal 本身解掉了。
- **GHCup(2020 起)**接手「裝 GHC/cabal/HLS」這件事,Stack 剩下的獨特優勢也沒了。
- **2026**:cabal 是社群預設、HLS 對 cabal 支援最完整、新套件的 README 都寫 `cabal build`。
  Stack 仍在維護,用它的專案不必改,但**新專案不再從 Stack 開始**。

所以看到 `stack.yaml` 就知道是 2015–2020 世代的專案;看到 `cabal.project` 是現代的。

## 常用指令複習

```powershell
cabal build all            # 建置
cabal repl <套件名>        # ghci 載入套件(改檔案後 :r 重載)
cabal test <套件名>        # 跑測試
cabal run wordcount -- 引數
cabal test level01-foundations -f solutions   # 用參考解答跑(驗證測試)
```

`--` 之後的東西是給你的程式的引數,不是給 cabal 的。
`-f solutions` 是 cabal flag:本專案用它切換 `hs-source-dirs` 到 `answers/`。

## 警告即負債

本課程開著 `-Wall -Wcompat -Wincomplete-uni-patterns -Wincomplete-record-updates`。
**把 warning 當 error 看待**:漏掉的 pattern、沒用到的變數,都是未來的 bug。
你的習題檔一開始滿是 unused-matches 警告 —— 實作完就會消失,順便當進度條。

前八章你已經看過的警告與它們的意思:

| 警告 | 章 | 它在說 |
|------|------|------|
| `-Wincomplete-patterns` | 2 | 你漏了一個案例,執行期會炸 |
| `-Wx-partial` | 2 | 你用了 `head`/`tail`,簽名說謊 |
| `-Wincomplete-record-updates` | 4 | sum type 上的 record 更新,某些建構子會炸 |
| `-Wmissing-signatures` | 1 | 頂層定義沒簽名 |
| `-Wtype-defaults` | 1 | 數字字面值沒人決定型別,GHC 幫你猜了 |
| `-Wunused-imports` / `-Wunused-matches` | — | 死程式碼 |

正式專案常再加 `-Werror`(CI 上把警告升級成錯誤)和 `-Wunused-packages`
(抓 `build-depends` 裡沒用到的套件)。

## 每日工作流(2026 標準)

1. VS Code + HLS:存檔即時看到型別錯誤,hover 看型別,`F12` 跳定義。
2. `cabal repl` 開著,小函式先在 ghci 驗證再寫進檔案。
3. `fourmolu` 格式化、`hlint` 給重構建議(裝法見 `00-setup/`)。
4. 測試驗收:`cabal test`。

一個實用的節奏:**先寫型別簽名,用 `undefined` 當本體,讓整個模組編過**,
再一個一個把 `undefined` 換成實作。這正是本課程習題檔的形狀 ——
它不是教學上的偷懶,是 Haskell 程式設計師真的這樣工作(typed holes:
把 `undefined` 換成 `_`,GHC 會告訴你這個洞需要什麼型別、範圍內有哪些東西可以填)。

## 常見誤區

1. 新增一個模組檔案卻忘了寫進 `exposed-modules` → `cabal build` 說找不到模組。
2. 用了新套件卻忘了加 `build-depends` → `Could not load module ... It is a member of the hidden package`。
3. 在模組裡用 `{-# LANGUAGE ... #-}` 開已經在 cabal 裡開過的擴充:無害但多餘,本專案已全部移到 cabal。
4. `cabal install` 拿來裝專案依賴 → 不對,那是裝**工具**(fourmolu、hlint)用的;依賴寫在 `build-depends`,`cabal build` 自動抓。
5. 把 warning 留到「之後再修」→ 之後永遠不會來。

## Level 1 結業檢查

- [ ] `cabal test level01-foundations` 全綠
- [ ] 能解釋:為什麼用 `Text` 不用 `String`?`foldl'` 和 `foldl` 差在哪?
- [ ] 能解釋:`NoFieldSelectors` + 點語法解決了什麼歷史問題?
- [ ] 能說出 Semigroup/Monoid 的三條 law,並舉一個違反的例子
- [ ] 能用 `readMaybe @Int` 與 `NonEmpty` 寫出 total 的解析函式(第 8 章)
- [ ] 能不查資料寫出:一個 sum type + 對它 total 的 pattern matching
- [ ] 知道 `main` 開頭那四行 UTF-8 設定在做什麼、為什麼 Windows 需要它

全部打勾 → 前進 `02-intermediate/`(Functor/Applicative/Monad、
惰性求值深入、錯誤處理、測試、並行)。
