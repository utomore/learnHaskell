-- | 第 2 章習題:pattern matching、guards、高階函式
module Exercises.E02Functions
  ( describeHp
  , clamp'
  , safeDivide
  , applyTwice
  , fizzbuzz
  ) where

import Data.Text (Text, pack)

-- | 用 guards 描述血量狀態:
-- <= 0 → "倒下"、< 20 → "瀕死"、< 70 → "受傷"、其他 → "健康"
describeHp :: Int -> Text
describeHp hp
  | hp <= 0 = "倒下"
  | hp < 20 = "瀕死"
  | hp < 70 = "受傷"
  | otherwise = "健康"

-- | 把數值限制在 [lo, hi] 區間內。
--
-- >>> clamp' 0 100 120
-- 100
-- >>> clamp' 0 100 (-5)
-- 0
clamp' :: Int -> Int -> Int -> Int
clamp' lo hi x = min hi $ max lo x

-- | 除以 0 回傳 Nothing,否則 Just 商。
-- 這是「total function」的習慣:不丟例外、用型別表達可能失敗。
safeDivide :: Double -> Double -> Maybe Double
safeDivide _ 0 = Nothing
safeDivide x y = Just (x/y)

-- | 把函式套用兩次。
--
-- >>> applyTwice (+3) 10
-- 16
applyTwice :: (a -> a) -> a -> a
applyTwice f x = f $ f x 

-- | 經典 FizzBuzz:3 的倍數 → "Fizz"、5 的倍數 → "Buzz"、
-- 15 的倍數 → "FizzBuzz"、其他 → 數字本身(提示:Data.Text.pack . show)
fizzbuzz :: Int -> Text
fizzbuzz n
  | n `mod` 15 == 0 = "FizzBuzz"
  | n `mod` 5 == 0 = "Buzz"
  | n `mod` 3 == 0 = "Fizz"
  | otherwise = (Data.Text.pack . show) n
