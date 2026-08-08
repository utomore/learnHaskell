-- | 第 3 章習題:list、遞迴、fold
module Exercises.E03Lists
  ( myLength
  , myReverse
  , safeHead
  , totalDamage
  , aliveCount
  , zipWithIndex
  ) where

-- foldl' 從 base 4.20 起由 Prelude 直接匯出,不用另外 import。

-- | 用「顯式遞迴」實作 length(不要呼叫 length)。
myLength :: [a] -> Int
myLength xs = undefined

-- | 用顯式遞迴實作 reverse(不要呼叫 reverse;效率差沒關係)。
myReverse :: [a] -> [a]
myReverse xs = undefined

-- | head 是 partial function(空 list 會爆炸),已是淘汰習慣。
-- 寫出 total 的版本:空 list 回傳 Nothing。
safeHead :: [a] -> Maybe a
safeHead xs = undefined

-- | 加總傷害。請用 foldl'(嚴格左摺,2026 的預設選擇;
-- 不要用 foldl —— 它會累積 thunk 造成 space leak)。
totalDamage :: [Int] -> Int
totalDamage hits = undefined

-- | 數出還活著(HP > 0)的敵人數量。提示:filter 與 length
aliveCount :: [Int] -> Int
aliveCount hps = undefined

-- | 幫每個元素標上從 0 開始的索引。提示:zip
--
-- >>> zipWithIndex "abc"
-- [(0,'a'),(1,'b'),(2,'c')]
zipWithIndex :: [a] -> [(Int, a)]
zipWithIndex xs = undefined
