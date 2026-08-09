-- | 第 7 章參考解答
module Exercises.E07Testing
  ( insertSorted
  , myReplicate
  ) where

insertSorted :: Int -> [Int] -> [Int]
insertSorted x [] = [x]
insertSorted x (y : ys)
  | x <= y = x : y : ys
  | otherwise = y : insertSorted x ys

myReplicate :: Int -> a -> [a]
myReplicate n x
  | n <= 0 = []
  | otherwise = x : myReplicate (n - 1) x
