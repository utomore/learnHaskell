# learnHaskell — 2026 現代 Haskell 教學系列

一套從零到打造遊戲的 Haskell 課程,以 **GHC 9.14 / GHC2024 / cabal** 為基準,
只教 2026 年 Haskell 社群的現行慣例,不教已被淘汰的思想。

## 學習路線圖

| 級別 | 目錄 | 主題 | 狀態 |
|------|------|------|------|
| 0 環境 | `00-setup/` | GHCup、cabal、HLS、ghci、格式化與 lint | ✅ |
| 1 初級 | `01-foundations/` | 型別、函式、ADT、typeclass、Text、IO、cabal 專案 | ✅ |
| 2 中級 | `02-intermediate/` | Functor/Applicative/Monad(以 laws 教)、惰性求值與 space leak、現代錯誤處理、測試(hspec + falsify)、async/STM | 🚧 規劃中 |
| 3 高級 | `03-advanced/` | GADTs、type families、DerivingVia、optics、streaming、效能調校 | 🚧 規劃中 |
| 4 進階 | `04-effects/` | Effect System 專章:effectful 為主、bluefin 對照、自訂 effect、選型史 | 🚧 規劃中 |
| 5 應用 | `05-games/` | **遊戲開發與 ECS**:終端 game loop → apecs ECS → 完整 2D 遊戲 | 🚧 規劃中 |

Level 5 為遊戲開發導向:先用純 Haskell 寫終端小遊戲練 game loop 與狀態管理,
再進入 **apecs**(Haskell 主流 Entity-Component-System 函式庫)與 2D 渲染,
最終整合 effect system 打造一個完整的小型遊戲。

## 如何使用

每一級是一個獨立的 cabal 套件,結構相同:

```
0X-level/
├── README.md      # 本級章節索引與驗收方式
├── notes/         # 教材(每章一份 markdown)
├── src/           # 可執行的範例程式
├── exercises/     # 習題骨架(把 undefined 換成你的實作)
├── answers/       # 參考解答(卡住再看!)
└── test/          # 自動測試 → 全綠即通關
```

工作流程:

```powershell
# 1. 讀 notes/ 的章節教材,搭配 ghci 實驗
cabal repl level01-foundations

# 2. 完成 exercises/ 內的習題(把 undefined 換掉)

# 3. 跑測試驗收,全綠代表本章完成
cabal test level01-foundations

# (想確認測試本身沒問題,可以用參考解答跑一次)
cabal test level01-foundations -f solutions
```

## 本課程的技術立場(2026)

**採用:** GHC2024、cabal + GHCup + HLS、`Text` 為預設字串型別、
`foldl'` 與嚴格求值習慣、total functions、`OverloadedRecordDot` + `NoFieldSelectors`、
effectful/bluefin 系 effect system、`async`/STM/ki 並行、hspec + falsify 測試、
apecs ECS 遊戲架構。

**不教(已淘汰):** monad 比喻教學法(burrito)、lazy IO、`String` 為預設、
`head`/`tail` 等 partial functions 習慣、深層 transformer stack 作為架構建議、
free-monad 系 effect system(polysemy/freer)、Stack 作為主要建置工具、
`ExceptT e IO` 反模式。
