-- | 第 8 章習題:async 與 STM
module Exercises.E08Concurrency
  ( transferGold
  , inParallel
  , raceFirst
  ) where

import Control.Concurrent.Async (concurrently, race)
import Control.Concurrent.STM (STM, TVar, modifyTVar')

-- | 轉帳:from 減 n、to 加 n。
-- 整個 STM 交易是原子的 —— 測試會開 100 條執行緒同時轉帳,
-- 驗證總額不變(用鎖寫這個是經典地獄,用 STM 是兩行)。
-- 提示:modifyTVar'(嚴格版;惰性的 modifyTVar 會在 TVar 裡堆 thunk)
transferGold :: TVar Int -> TVar Int -> Int -> STM ()
transferGold from to n = undefined

-- | 同時執行兩個 IO 動作,等兩個都完成。
-- 提示:async 套件的 concurrently 就是這個型別。
inParallel :: IO a -> IO b -> IO (a, b)
inParallel ioA ioB = undefined

-- | 兩個動作賽跑,誰先完成就用誰的結果(另一個會被取消)。
-- 提示:race :: IO a -> IO b -> IO (Either a b),
-- 兩邊同型別時用 either id id 拆掉 Either。
raceFirst :: IO a -> IO a -> IO a
raceFirst ioA ioB = undefined
