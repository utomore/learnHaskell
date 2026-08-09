-- | 第 5 章參考解答
module Exercises.E05Laziness
  ( Acc (..)
  , average
  , firstNegative
  , takeUntilBudget
  ) where

import Data.List (find)

data Acc = Acc !Int !Int
  deriving stock (Eq, Show)

average :: [Int] -> Maybe Double
average [] = Nothing
average xs = Just (fromIntegral total / fromIntegral count)
  where
    Acc total count = foldl' step (Acc 0 0) xs
    step (Acc s c) x = Acc (s + x) (c + 1)

firstNegative :: [Int] -> Maybe Int
firstNegative = find (< 0)

takeUntilBudget :: Int -> [Int] -> [Int]
takeUntilBudget _ [] = []
takeUntilBudget budget (c : cs)
  | c <= budget = c : takeUntilBudget (budget - c) cs
  | otherwise = []
