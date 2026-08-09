# Level 2 — 中級

從「會寫 Haskell」到「懂 Haskell 的抽象與執行模型」。

## 章節

| 章 | 教材 | 習題 |
|----|------|------|
| 1 Functor | `notes/01-functors.md` | `E01Functors.hs` |
| 2 Applicative | `notes/02-applicative.md` | `E02Applicative.hs` |
| 3 Monad | `notes/03-monads.md` | `E03Monads.hs` |
| 4 Foldable/Traversable | `notes/04-foldable-traversable.md` | `E04Traverse.hs` |
| 5 惰性求值與 space leak | `notes/05-laziness.md` | `E05Laziness.hs` |
| 6 現代錯誤處理 | `notes/06-error-handling.md` | `E06Errors.hs` |
| 7 測試(hspec + hedgehog) | `notes/07-testing.md` | `E07Testing.hs` |
| 8 並行(async + STM) | `notes/08-concurrency.md` | `E08Concurrency.hs` |
| 9 Transformers 識讀 | `notes/09-transformers-literacy.md` | (結業檢查) |

## 使用方式

```powershell
cabal repl level02-intermediate    # 跟著教材實驗
cabal test level02-intermediate    # 驗收(54 個測試全綠 = 通關)
cabal test level02-intermediate -f solutions   # 用參考解答驗證測試
```

教學立場延續 Level 1:Functor/Applicative/Monad 以「型別 + laws +
使用場景」教學,不用比喻;錯誤處理與並行直接教 2026 現行做法,
淘汰做法(lazy IO、ExceptT-over-IO、裸 forkIO、鎖)只作為
「為什麼不這樣寫」出現。
