-- | 第 2 章參考解答
module Exercises.E02Functions
  ( describeHp
  , clamp'
  , safeDivide
  , applyTwice
  , fizzbuzz
  ) where

import Data.Text (Text)
import Data.Text qualified as T

describeHp :: Int -> Text
describeHp hp
  | hp <= 0 = "倒下"
  | hp < 20 = "瀕死"
  | hp < 70 = "受傷"
  | otherwise = "健康"

clamp' :: Int -> Int -> Int -> Int
clamp' lo hi x
  | x < lo = lo
  | x > hi = hi
  | otherwise = x

safeDivide :: Double -> Double -> Maybe Double
safeDivide _ 0 = Nothing
safeDivide x y = Just (x / y)

applyTwice :: (a -> a) -> a -> a
applyTwice f = f . f

fizzbuzz :: Int -> Text
fizzbuzz n
  | n `mod` 15 == 0 = "FizzBuzz"
  | n `mod` 3 == 0 = "Fizz"
  | n `mod` 5 == 0 = "Buzz"
  | otherwise = T.pack (show n)
