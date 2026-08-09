# 第 9 章 — 生態系識讀:Monad Transformers 與 ReaderT

> 本章沒有習題,目標是**讀懂既有程式碼**。這些技術大量存在於
> 現役函式庫與教學文章中,你必須認得;但新架構我們在 Level 4
> 會用 effect system(effectful)—— 原因在文末。

## 問題:monad 只能一次一種

`Maybe` 給你失敗、`Reader` 給你環境、`State` 給你狀態、`IO` 給你副作用。
同時要多種呢?Transformer 把 monad 疊起來:

```haskell
ReaderT Config IO a          -- 能讀 Config,也能做 IO
StateT GameState (ReaderT Config IO) a   -- 再疊一層狀態
```

每層的操作要 `lift` 到正確的層;`mtl` 套件用 typeclass 省掉 lift:

```haskell
foo :: (MonadReader Config m, MonadIO m) => m ()
foo = do
  cfg <- ask                   -- 來自 MonadReader
  liftIO (print cfg.port)      -- 來自 MonadIO
```

## ReaderT pattern:上一個時代的標準架構

2016–2023 的主流 Haskell 應用架構:**整個 app 就一層
`ReaderT Env IO`**,`Env` 裡放 logger、資料庫連線池、設定:

```haskell
newtype App a = App (ReaderT Env IO a)
```

它是對「深疊 transformer」的反動:狀態放 `Env` 裡的 `TVar`(而不是
`StateT`)、錯誤用例外(而不是 `ExceptT`,呼應第 6 章)。
看到 `newtype App a = App (ReaderT Env IO a)` 你就知道這是什麼流派。

## 為什麼新專案不從這裡開始

1. **n² instance 問題**:mtl 每加一種效果,要為每個 transformer
   寫一個 instance,自訂效果的成本高。
2. **語意陷阱**:疊的順序改變行為(`StateT` 在 `ExceptT` 之上或之下,
   錯誤發生時狀態是否回滾完全不同),而這藏在型別裡不明顯。
3. **效果不夠細**:`MonadIO` 一開就是整個 IO,無法說「這個函式
   只能寫 log 和查資料庫」。

Effect system(Level 4 的 **effectful**)保留「函式簽名宣告它需要
哪些效果」的好處,去掉疊層與 n² 成本 —— 而它的內部實作恰好就是
ReaderT pattern 的工業化:所以這章的概念不會白學。

## 你需要帶走的閱讀能力

- `ReaderT` / `StateT` / `ExceptT` 各給什麼能力、`lift` 在做什麼
- `MonadReader`/`MonadState`/`MonadIO` 約束怎麼讀
- 認出 ReaderT pattern 與它的 `Env`
- 警覺:`ExceptT e IO` 出現時,想起第 6 章的反模式討論

## Level 2 結業檢查

- [ ] `cabal test level02-intermediate` 54 個測試全綠
- [ ] 能說出 Functor / Applicative / Monad 各自多了什麼能力,並各舉一個實例
- [ ] 能解釋 `traverse` 的型別,以及它取代了哪種手寫遞迴
- [ ] 能說明 space leak 怎麼發生、`foldl'` 和 `!` 欄位為什麼能救
- [ ] 能複述「領域錯誤用 Either + ADT、IO 失敗用例外收編」的分工
- [ ] 寫得出一條 hedgehog 性質測試
- [ ] 能解釋 STM 比鎖好在哪(組合性、無死鎖)

全綠之後 → `03-advanced/`(GADTs、type families、optics、
streaming、效能調校)。
