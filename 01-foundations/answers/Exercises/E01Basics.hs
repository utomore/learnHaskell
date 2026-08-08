-- | 第 1 章參考解答
module Exercises.E01Basics
  ( hitPoints
  , distance
  , xpForNextLevel
  , isCritical
  , secondsToHms
  ) where

hitPoints :: Int -> Int -> Int
hitPoints hp dmg = max 0 (hp - dmg)

distance :: Double -> Double -> Double -> Double -> Double
distance x1 y1 x2 y2 = sqrt ((x2 - x1) ^ (2 :: Int) + (y2 - y1) ^ (2 :: Int))

xpForNextLevel :: Int -> Int
xpForNextLevel level = level * 100 + 50

isCritical :: Int -> Bool
isCritical roll = roll >= 95

secondsToHms :: Int -> (Int, Int, Int)
secondsToHms total = (h, m, s)
  where
    (h, rest) = total `divMod` 3600
    (m, s) = rest `divMod` 60
