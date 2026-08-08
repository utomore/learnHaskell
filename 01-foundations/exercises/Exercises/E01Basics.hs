-- | 第 1 章習題:運算式、型別、簡單函式
--
-- 把每個 undefined 換成你的實作,然後執行:
--
-- > cabal test level01-foundations
--
-- 卡住了可以看 answers/Exercises/E01Basics.hs(先自己想!)
module Exercises.E01Basics
  ( hitPoints
  , distance
  , xpForNextLevel
  , isCritical
  , secondsToHms
  ) where

-- | 扣血:HP 減去傷害,但不得低於 0。
--
-- >>> hitPoints 100 30
-- 70
-- >>> hitPoints 20 50
-- 0
hitPoints :: Int -> Int -> Int
hitPoints hp dmg = undefined

-- | 2D 平面上兩點 (x1,y1) (x2,y2) 的距離。提示:sqrt
--
-- >>> distance 0 0 3 4
-- 5.0
distance :: Double -> Double -> Double -> Double -> Double
distance x1 y1 x2 y2 = undefined

-- | 升到下一級需要的經驗值:等級 * 100 + 50。
--
-- >>> xpForNextLevel 3
-- 350
xpForNextLevel :: Int -> Int
xpForNextLevel level = undefined

-- | 骰出 95(含)以上就是暴擊。
--
-- >>> isCritical 97
-- True
isCritical :: Int -> Bool
isCritical roll = undefined

-- | 把秒數換算成 (時, 分, 秒)。提示:div 與 mod
--
-- >>> secondsToHms 3725
-- (1,2,5)
secondsToHms :: Int -> (Int, Int, Int)
secondsToHms total = undefined
