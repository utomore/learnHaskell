# 第 8 章 — 並行:async 與 STM

## Haskell 執行緒超便宜

GHC 的綠色執行緒幾 KB 就一條,開十萬條是日常操作。
底層原語是 `forkIO`,但**日常不直接用它** —— 手管執行緒
跟手管 malloc 一樣容易漏。用下面兩層抽象。

(記得編譯要加 `-threaded`,本套件的測試已經開了
`-threaded -with-rtsopts=-N`。)

## async 套件:有結果、會傳錯的並行

```haskell
import Control.Concurrent.Async

concurrently :: IO a -> IO b -> IO (a, b)   -- 兩個一起跑,等全部
race         :: IO a -> IO b -> IO (Either a b)  -- 賽跑,輸家被取消
mapConcurrently :: Traversable t => (a -> IO b) -> t a -> t (IO b)  -- 並行 traverse
withAsync    :: IO a -> (Async a -> IO b) -> IO b  -- 有範圍的背景工作
```

關鍵性質:**一邊丟例外,另一邊會被取消,例外會傳回主執行緒**。
不會有殭屍執行緒默默吞掉錯誤 —— 這是它比裸 `forkIO` 重要的原因。

```haskell
(monsters, terrain) <- concurrently loadMonsters loadTerrain
```

## STM:可組合的共享狀態交易

鎖(mutex)最大的問題是**不可組合**:兩段各自正確的加鎖程式碼,
組起來會死鎖。STM(Software Transactional Memory)用交易取代鎖:

```haskell
import Control.Concurrent.STM

transferGold :: TVar Int -> TVar Int -> Int -> STM ()
transferGold from to n = do
  modifyTVar' from (subtract n)    -- 注意 ':嚴格版,別在 TVar 裡堆 thunk
  modifyTVar' to (+ n)

-- 在 IO 裡執行整個交易,原子性由執行期保證
atomically (transferGold alice bob 100)
```

- 交易內只能做 STM 操作(型別擋住你在交易裡發射飛彈);
  衝突時執行期自動重試,**不可能死鎖**。
- `retry`:條件不滿足就掛起,等相關 TVar 變化再醒來
  (拿來寫工作佇列、等待遊戲事件,取代輪詢)。
- 兩個 STM 函式組合起來仍是原子的 —— 這是鎖做不到的。

100 條執行緒同時轉帳、總額分毫不差 —— 本章測試就是這麼驗的。

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

## 習題

`exercises/Exercises/E08Concurrency.hs` → `cabal test level02-intermediate`
