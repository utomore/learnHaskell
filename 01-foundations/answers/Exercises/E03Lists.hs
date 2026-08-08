-- | 第 3 章參考解答
module Exercises.E03Lists
  ( myLength
  , myReverse
  , safeHead
  , totalDamage
  , aliveCount
  , zipWithIndex
  ) where

myLength :: [a] -> Int
myLength [] = 0
myLength (_ : xs) = 1 + myLength xs

myReverse :: [a] -> [a]
myReverse [] = []
myReverse (x : xs) = myReverse xs ++ [x]

safeHead :: [a] -> Maybe a
safeHead [] = Nothing
safeHead (x : _) = Just x

totalDamage :: [Int] -> Int
totalDamage = foldl' (+) 0

aliveCount :: [Int] -> Int
aliveCount = length . filter (> 0)

zipWithIndex :: [a] -> [(Int, a)]
zipWithIndex = zip [0 ..]
