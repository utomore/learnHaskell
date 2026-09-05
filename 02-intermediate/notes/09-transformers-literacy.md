# 第 9 章 — 生態系識讀:Monad Transformers 與 ReaderT

> 本章沒有習題,目標是**讀懂既有程式碼**。這些技術大量存在於
> 現役函式庫與教學文章中,你必須認得;但新架構我們在 Level 4
> 會用 effect system(effectful)—— 原因在文末。

## 問題:monad 只能一次一種

`Maybe` 給你失敗、`Reader` 給你環境、`State` 給你狀態、`IO` 給你副作用。
同時要多種呢?第 3 章說過,一個 do 區塊裡所有 `<-` 必須是同一個 monad——
`Maybe` 和 `IO` 不能直接混。Transformer 把 monad 疊起來:

```haskell
ReaderT Config IO a          -- 能讀 Config,也能做 IO
StateT GameState (ReaderT Config IO) a   -- 再疊一層狀態
```

### 三個 transformer 的定義(直接看,沒有魔法)

```haskell
newtype ReaderT r m a = ReaderT { runReaderT :: r -> m a }
newtype StateT  s m a = StateT  { runStateT  :: s -> m (a, s) }
newtype ExceptT e m a = ExceptT (m (Either e a))
```

- `ReaderT r m a`:「給我一個 `r`,我還你一個 `m a`」——就是把環境當引數傳,
  只是幫你把傳遞自動化。
- `StateT s m a`:「給我舊狀態,我還你 `m (結果, 新狀態)`」——
  Level 1 的 `World -> World` 更新加上一個回傳值。
- `ExceptT e m a`:「一個 `m` 動作,裡面裝著 `Either e a`」——第 6 章的 `Either`
  包在別的 monad 裡。

每個都是 `newtype`,執行期零成本;`m` 是「下面那一層」,最底通常是 `IO`
或 `Identity`(於是 `State s = StateT s Identity`)。

### `lift`:把下層的動作抬上來

```haskell
lift   :: (MonadTrans t, Monad m) => m a -> t m a
liftIO :: MonadIO m => IO a -> m a       -- 不管疊幾層,直接把 IO 抬到最上面
```

在 `StateT Int IO` 裡想 `putStrLn`,不能直接寫——它是 `IO ()`,
而 do 區塊要的是 `StateT Int IO ()`:

```haskell
tick :: StateT Int IO ()
tick = do
  n <- get
  lift (putStrLn ("tick " ++ show n))   -- 沒有 lift 就編不過(見下面的錯誤訊息)
  put (n + 1)
```

疊三層時,底層的動作要 `lift . lift`——這是 transformer 最讓人厭煩的地方,
也是 `mtl` 存在的理由。

## mtl:用 typeclass 省掉 lift

`mtl` 套件為每種能力定義一個 class:

```haskell
class Monad m => MonadReader r m | m -> r where
  ask   :: m r
  local :: (r -> r) -> m a -> m a

class Monad m => MonadState s m | m -> s where
  get :: m s
  put :: s -> m ()
```

函式簽名改成寫**約束**而不是具體的疊法:

```haskell
foo :: (MonadReader Config m, MonadIO m) => m ()
foo = do
  cfg <- ask                   -- 來自 MonadReader
  liftIO (print cfg.port)      -- 來自 MonadIO
```

`ask` 會自己穿透到正確的那一層,呼叫端愛怎麼疊就怎麼疊。
`| m -> r` 是 functional dependency:「知道 `m` 就知道 `r`」,
讓型別推論不用你標註環境型別。

## ReaderT pattern:上一個時代的標準架構

2016–2023 的主流 Haskell 應用架構:**整個 app 就一層
`ReaderT Env IO`**,`Env` 裡放 logger、資料庫連線池、設定。完整最小範例:

```haskell
data Env = Env
  { logger :: Text -> IO ()
  , score  :: TVar Int              -- 可變狀態放 TVar,不用 StateT
  }

newtype App a = App (ReaderT Env IO a)
  deriving newtype (Functor, Applicative, Monad, MonadIO, MonadReader Env)

runApp :: Env -> App a -> IO a
runApp env (App m) = runReaderT m env

logMsg :: Text -> App ()
logMsg msg = do
  env <- ask
  liftIO (env.logger msg)

addScore :: Int -> App ()
addScore n = do
  env <- ask
  liftIO (atomically (modifyTVar' env.score (+ n)))
  logMsg "得分!"

main :: IO ()
main = do
  sv <- newTVarIO 0
  let env = Env {logger = TIO.putStrLn . ("[log] " <>), score = sv}
  runApp env (addScore 10 >> addScore 5)
  readTVarIO sv >>= print       -- 15
```

`deriving newtype (..., MonadReader Env)` 一行就把 `ReaderT` 的所有能力
借給 `App`(第 1 級 deriving strategies 的 `newtype` 策略)。

它是對「深疊 transformer」的反動:狀態放 `Env` 裡的 `TVar`(而不是
`StateT`)、錯誤用例外(而不是 `ExceptT`,呼應第 6 章)。
看到 `newtype App a = App (ReaderT Env IO a)` 你就知道這是什麼流派。

## 舊做法 → 新做法:從深疊到 ReaderT 再到 effect system

**深疊 transformer(2000 年代到 2015)**:`StateT Game (ExceptT Err (ReaderT Cfg IO))`
這種簽名在當年的程式碼裡很常見,教材也這樣教。三個實際問題讓社群放棄它:

1. **n² instance 問題**。mtl 的每個 class 都要為每個 transformer 寫一個
   「穿透」instance。看 `:i MonadState` 的實際輸出:

   ```
   instance MonadState s m => MonadState s (ExceptT e m)
   instance MonadState s m => MonadState s (ReaderT r m)
   instance Monad m       => MonadState s (StateT s m)
   ```

   `MonadReader` 也有同樣一組,`MonadError`、`MonadWriter` 各一組……
   n 種能力 × n 種 transformer = n² 個 instance。你自訂一個效果
   (例如 `MonadLogger`)就得為 `StateT`、`ReaderT`、`ExceptT`……全部補一遍,
   而且 mtl 自己的 class 也不認識你的 transformer。

2. **疊的順序改變語意,而且藏在型別裡**。`StateT s (ExceptT e m)` 錯誤發生時
   狀態**丟失**(回滾);`ExceptT e (StateT s m)` 錯誤發生時狀態**保留**。
   兩個簽名只差順序,行為完全不同,而看程式碼的人很難一眼判斷。

3. **效果太粗**。`MonadIO m` 一開就是整個 IO,無法說「這個函式只能寫 log
   和查資料庫,不能刪檔案」。

**ReaderT pattern(2017 起)**:Snoyman 的文章主張「只疊一層,可變狀態用 `TVar`,
錯誤用例外」,把 1、2 兩個問題砍掉——沒有疊層就沒有順序問題,也不用 n² instance。
代價是問題 3 沒解:所有東西都在 `IO` 裡,測試時要 mock `Env` 裡的函式欄位。

**Effect system(2022 起主流)**:保留「函式簽名宣告它需要哪些效果」的好處
(`(Log :> es, Db :> es) => Eff es ()`),去掉疊層與 n² 成本。選型史:

| 年份 | 函式庫 | 做法 | 為什麼沒成為 2026 主流 |
|---|---|---|---|
| 2013 | extensible-effects(Kiselyov 等人的論文) | free monad + open union | 慢(每次 bind 配置)、型別錯誤訊息糟 |
| 2017 | freer-simple | 同上,API 較乾淨 | 同上的效能問題 |
| 2019 | polysemy | free monad,靠 GHC plugin 改善推論 | 效能仍差、依賴 plugin、維護放緩 |
| 2019 | fused-effects | typeclass 融合,效能好 | 自訂效果的樣板多 |
| 2022 | **effectful** | 內部就是 `ReaderT Env IO`,效果是 `Env` 裡的欄位 | **成為主流**:效能等於手寫 IO、錯誤訊息正常、與 mtl 互通 |
| 2024 | bluefin | 同 effectful 的底層,但效果用**值**傳遞而非型別層級的 `:>` 約束 | 新、社群小;推論更簡單,是 effectful 的有力對照 |

effectful 勝出的原因很樸素:它放棄了 free monad 的理論優雅,
直接把 ReaderT pattern 工業化——所以這章的概念不會白學,
Level 4 打開 effectful 的原始碼你會看到熟悉的 `ReaderT`。

## 你會看到的錯誤訊息

在 transformer 裡直接用下層的動作:

```haskell
tick :: StateT Int IO ()
tick = do
  n <- get
  putStrLn ("tick " ++ show n)    -- 忘了 lift
  put (n + 1)
```

```
E9.hs:6:3: error: [GHC-83865]
    • Couldn't match type ‘IO’ with ‘StateT Int IO’
      Expected: StateT Int IO ()
        Actual: IO ()
    • In a stmt of a 'do' block: putStrLn ("tick " ++ show n)
```

`Expected: StateT Int IO () / Actual: IO ()`:do 區塊的 monad 是 `StateT Int IO`,
你放了一個裸的 `IO`。修法:`lift (putStrLn ...)` 或 `liftIO (putStrLn ...)`。
讀開源碼看到大量 `liftIO`,就是在做這件事。

## ghci 實驗

```haskell
ghci> import Control.Monad.State
ghci> :i StateT
newtype StateT s m a = StateT {runStateT :: s -> m (a, s)}
ghci> :t lift
lift :: (MonadTrans t, Monad m) => m a -> t m a
ghci> :t liftIO
liftIO :: MonadIO m => IO a -> m a
ghci> runStateT (modify (+ 1) >> get) 10
(11,11)
ghci> :i MonadState        -- 看 n² instance 問題的實物
```

## 你需要帶走的閱讀能力

- `ReaderT` / `StateT` / `ExceptT` 各給什麼能力、`lift` 在做什麼
- `MonadReader`/`MonadState`/`MonadIO` 約束怎麼讀
- 認出 ReaderT pattern 與它的 `Env`
- 警覺:`ExceptT e IO` 出現時,想起第 6 章的反模式討論
- 看到 `Eff es`、`:>`、`Sem r`、`Member`,知道那是 effect system 家族的哪一支

## 常見誤區

- **新專案從三層 transformer 開始。** 先 `ReaderT Env IO`(或直接 Level 4 的 effectful)。
- **`StateT` 放遊戲狀態。** 並行時會炸(狀態不在共享記憶體裡);用 `TVar`。
- **以為 `liftIO` 是免費的。** 它是,執行期零成本;但它代表「這裡可以做任何 IO」,
  effect system 就是為了把這個「任何」縮小。
- **疊的順序隨便寫。** `StateT` 與 `ExceptT` 的相對順序決定錯誤時狀態是否回滾。

## Level 2 結業檢查

- [ ] `cabal test level02-intermediate` 全綠
- [ ] 能說出 Functor / Applicative / Monad 各自多了什麼能力,並各舉一個實例
- [ ] 能寫出 Functor 兩條、Monad 三條 law,並解釋違反時哪個日常函式會壞
- [ ] 能解釋 `traverse` 的型別,以及它取代了哪種手寫遞迴
- [ ] 能說明 space leak 怎麼發生、`foldl'` 和 `!` 欄位為什麼能救、`seq` 和 `deepseq` 差在哪
- [ ] 能複述「領域錯誤用 Either + ADT、IO 失敗用例外收編」的分工,以及 `ExceptT e IO` 為什麼壞
- [ ] 寫得出一條 hedgehog 性質測試,並且知道怎麼確認它「會紅」
- [ ] 能解釋 STM 比鎖好在哪(組合性、無死鎖),以及 `modifyTVar'` 的 `'` 為什麼重要
- [ ] 看到 `newtype App a = App (ReaderT Env IO a)` 知道它是什麼、為什麼這樣設計

全綠之後 → `03-advanced/`(GADTs、type families、optics、
streaming、效能調校)。
