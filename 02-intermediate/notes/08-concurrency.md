# 第 8 章 — 並行:async 與 STM

## Haskell 執行緒超便宜

GHC 的綠色執行緒幾 KB 就一條,開十萬條是日常操作。
底層原語是 `forkIO`,但**日常不直接用它** —— 手管執行緒
跟手管 malloc 一樣容易漏。用下面兩層抽象。

### 綠色執行緒與 OS 執行緒

`forkIO` 開的是 **GHC 自己排程的輕量執行緒**,不是 OS 執行緒。
RTS 把它們多工在少數幾個 OS 執行緒(稱為 **capability**)上:

| 編譯/執行選項 | 意義 |
|---|---|
| 不加 `-threaded` | 只有一個 capability:所有綠色執行緒輪流跑在一顆核心上。並行(concurrency)有,平行(parallelism)沒有 |
| `-threaded` | 啟用多核心 RTS |
| `+RTS -N` | capability 數 = CPU 核心數(`-N4` 指定 4 個) |

本套件的測試已經開了 `-threaded -with-rtsopts=-N`。
記住:**沒有 `-threaded` 的程式,`mapConcurrently` 也只會在一顆核心上輪流跑**——
邏輯正確,但不會變快。這是「明明用了 async 怎麼沒加速」的第一嫌疑犯。

## 舊做法 → 新做法:`forkIO` 與 `MVar`

`forkIO`(1996 年 Concurrent Haskell 論文)與 `MVar`(帶鎖的單格信箱)
是 Haskell 並行的第一代 API,至今仍是所有高階抽象的地基。
問題出在**錯誤處理**:`forkIO` 開出去的執行緒是孤兒,它死掉沒人知道。

```haskell
_ <- forkIO (throwIO (ErrorCall "載入怪物表失敗"))
threadDelay 100000
putStrLn "主執行緒繼續跑,以為一切正常"
```

真實輸出(stderr 印了一行,主執行緒毫無反應):

```
fork.exe: Uncaught exception ghc-internal:GHC.Internal.Exception.ErrorCall:

載入怪物表失敗

HasCallStack backtrace:
  throwIO, called at app\Fork.hs:13:16 in pk-0-inplace-fork:Main

主執行緒繼續跑,以為一切正常
```

遊戲裡這代表:資源載入執行緒炸了,主迴圈照跑,畫面上永遠少一隻怪,
你要在 log 裡翻很久才找到那一行。要自己補救就得手寫「用 `MVar` 把結果或例外傳回來、
主執行緒記得等、記得取消、記得例外時清理」——每個人寫的都有 bug。
`async` 套件(Simon Marlow,2012)就是把這套補救**寫對一次**。

`MVar` 你仍會到處看到(函式庫內部、`async` 自己的實作),讀得懂即可:
`newEmptyMVar`/`putMVar`/`takeMVar`,一格信箱,空的時候 `take` 會等。
新程式碼的共享狀態用下一節的 STM。

## async 套件:有結果、會傳錯的並行

```haskell
import Control.Concurrent.Async

concurrently    :: IO a -> IO b -> IO (a, b)           -- 兩個一起跑,等全部
race            :: IO a -> IO b -> IO (Either a b)     -- 賽跑,輸家被取消
mapConcurrently :: Traversable t => (a -> IO b) -> t a -> IO (t b)  -- 並行 traverse
withAsync       :: IO a -> (Async a -> IO b) -> IO b   -- 有範圍的背景工作
```

`mapConcurrently` 的型別就是 `traverse` 把 `f` 換成 `IO` 再加上「平行跑」——
它能存在,正是因為 `traverse` 只要求 Applicative(第 2、4 章)。

關鍵性質:**一邊丟例外,另一邊會被取消,例外會傳回主執行緒**。

```haskell
r <- try (concurrently (pure 1) (throwIO (ErrorCall "載入地形失敗")))
case r of
  Left (e :: SomeException) -> putStrLn ("主執行緒收到:" ++ displayException e)
  Right (a, ()) -> print a
```

```
主執行緒收到:載入地形失敗
```

不會有殭屍執行緒默默吞掉錯誤 —— 這是它比裸 `forkIO` 重要的原因。

```haskell
(monsters, terrain) <- concurrently loadMonsters loadTerrain
```

`withAsync` 是「範圍」版本:回呼結束(正常或例外)時背景工作一定被取消,
不會外洩。凡是「開一條背景執行緒然後等它」都該用它而不是 `async` + `wait`。

## STM:可組合的共享狀態交易

鎖(mutex)最大的問題是**不可組合**:兩段各自正確的加鎖程式碼,
組起來會死鎖(A 先鎖甲再鎖乙、B 先鎖乙再鎖甲)。
STM(Software Transactional Memory,GHC 2005 年內建)用交易取代鎖:

```haskell
import Control.Concurrent.STM

transferGold :: TVar Int -> TVar Int -> Int -> STM ()
transferGold from to n = do
  modifyTVar' from (subtract n)    -- 注意 ':嚴格版,別在 TVar 裡堆 thunk
  modifyTVar' to (+ n)

-- 在 IO 裡執行整個交易,原子性由執行期保證
atomically (transferGold alice bob 100)
```

- 交易內只能做 STM 操作(型別擋住你在交易裡發射飛彈——
  因為交易可能被重跑,裡面若有 IO 就會重複執行);
  衝突時執行期自動重試,**不可能死鎖**。
- 兩個 STM 函式組合起來仍是原子的 —— 這是鎖做不到的。

### `retry` 與 `orElse`

```haskell
retry  :: STM a                       -- 條件不滿足:掛起,等相關 TVar 變化再重跑
orElse :: STM a -> STM a -> STM a     -- 左邊 retry 就試右邊
check  :: Bool -> STM ()              -- check b = if b then pure () else retry
```

用它們寫一個「從任務佇列拿一件工作,沒有就等」,取代輪詢:

```haskell
takeJob :: TVar [Job] -> STM Job
takeJob q = do
  jobs <- readTVar q
  case jobs of
    [] -> retry                       -- 沒工作:睡到有人 writeTVar q 為止
    (j : rest) -> writeTVar q rest >> pure j

-- 兩個佇列,優先拿高優先的;都空才等
takeAny :: TVar [Job] -> TVar [Job] -> STM Job
takeAny high low = takeJob high `orElse` takeJob low
```

`retry` 不是忙等:RTS 記下這筆交易讀過哪些 `TVar`,只有它們被改動才喚醒。
`orElse` 讓「等待」也能組合——這在鎖的世界裡是條件變數加一堆手工旗標。

100 條執行緒同時轉帳、總額分毫不差 —— 本章測試就是這麼驗的。

### `TVar` 裡的 space leak

`modifyTVar`(沒有 `'`)只是把「一個還沒算的函式套用」放進 `TVar`。
一百萬次 `modifyTVar gold (+ i)` 之後,`TVar` 裡是一百萬層 thunk,
第一次 `readTVar` 才一次算完。`+RTS -s` 的真實數字:

```
modifyTVar  :  38,551,856 bytes maximum residency    -- 38 MB 的欠條
modifyTVar' :      44,480 bytes maximum residency    -- 每次立刻算
```

遊戲的世界狀態若放在 `TVar` 裡,每幀 `modifyTVar` 就是每幀多一層——
這正是第 5 章「長壽資料要嚴格」在並行世界的版本。**規則:永遠 `modifyTVar'`**。

## 結構化並行:ki

async 已經很好,但執行緒的**生命週期**仍靠人審慎使用 `withAsync`。
**ki** 套件把「所有子執行緒必須在 scope 結束前收攤」變成 API 保證
(structured concurrency,同 Java Loom / Python trio 的思想):

```haskell
Ki.scoped \scope -> do
  Ki.fork_ scope worker1
  Ki.fork_ scope worker2
  ...   -- 離開 scope 時保證全部收乾淨
```

先用 async 打好基礎,Level 5 遊戲的背景系統(音效、資源載入)
會再回來談 ki。

## 你會看到的錯誤訊息

在 `atomically` 外面直接用 STM 操作:

```haskell
main = do
  gold <- newTVarIO (0 :: Int)
  n <- readTVar gold          -- 忘了 atomically
  print n
```

```
E8.hs:6:8: error: [GHC-83865]
    • Couldn't match type ‘STM’ with ‘IO’
      Expected: IO Int
        Actual: STM Int
    • In a stmt of a 'do' block: n <- readTVar gold
```

`Expected: IO Int / Actual: STM Int`:你在 IO 的 do 區塊裡放了一個 STM 動作。
這正是型別系統在保護交易邊界——STM 動作**只能**在 `atomically` 裡跑。
修法:`n <- atomically (readTVar gold)`,或單純讀值用 `readTVarIO gold`。
反過來在 STM 區塊裡寫 `putStrLn` 會得到 `Couldn't match type ‘IO’ with ‘STM’`,
同一個保護的另一面。

## ghci 實驗

```haskell
ghci> import Control.Concurrent.Async
ghci> import Control.Concurrent.STM
ghci> :t mapConcurrently
mapConcurrently :: Traversable t => (a -> IO b) -> t a -> IO (t b)
ghci> :t race
race :: IO a -> IO b -> IO (Either a b)
ghci> race (threadDelay 50000 >> pure "slow") (pure "fast")
Right "fast"
ghci> mapConcurrently (\n -> pure (n * 2)) [1, 2, 3]
[2,4,6]
ghci> :t retry
retry :: STM a
ghci> :t orElse
orElse :: STM a -> STM a -> STM a
```

## 常見誤區

- **沒開 `-threaded` 就期待加速。** 只有並行沒有平行。
- **`forkIO` 然後忘了它。** 例外被吞、資源不釋放;用 `withAsync`/`concurrently`。
- **在 STM 交易裡做 IO。** 型別不允許,理由是交易會重跑。
- **`modifyTVar` 沒加 `'`。** 每次都堆一層 thunk。
- **用 `SomeException` 抓所有例外再繼續。** 會吃掉 `async` 的取消訊號
  (`AsyncCancelled`),導致取消失效。只在最外層抓全部。

## 習題

`exercises/Exercises/E08Concurrency.hs` → `cabal test level02-intermediate`
