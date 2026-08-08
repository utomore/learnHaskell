-- | 第 2 章習題:pattern matching、guards、高階函式
module Exercises.E02Functions
  ( describeHp
  , clamp'
  , safeDivide
  , applyTwice
  , fizzbuzz
  ) where

import Data.Text (Text)

-- | 用 guards 描述血量狀態:
-- <= 0 → "倒下"、< 20 → "瀕死"、< 70 → "受傷"、其他 → "健康"
describeHp :: Int -> Text
describeHp hp = undefined

-- | 把數值限制在 [lo, hi] 區間內。
--
-- >>> clamp' 0 100 120
-- 100
-- >>> clamp' 0 100 (-5)
-- 0
clamp' :: Int -> Int -> Int -> Int
clamp' lo hi x = undefined

-- | 除以 0 回傳 Nothing,否則 Just 商。
-- 這是「total function」的習慣:不丟例外、用型別表達可能失敗。
safeDivide :: Double -> Double -> Maybe Double
safeDivide x y = undefined

-- | 把函式套用兩次。
--
-- >>> applyTwice (+3) 10
-- 16
applyTwice :: (a -> a) -> a -> a
applyTwice f x = undefined

-- | 經典 FizzBuzz:3 的倍數 → "Fizz"、5 的倍數 → "Buzz"、
-- 15 的倍數 → "FizzBuzz"、其他 → 數字本身(提示:Data.Text.pack . show)
fizzbuzz :: Int -> Text
fizzbuzz n = undefined
