-- | 第 7 章習題:效能調校
--
-- 把 undefined 換成實作 → cabal test level03-advanced
-- 測試會餵百萬級輸入:寫出洩漏版會明顯變慢,甚至爆記憶體。
module Exercises.E07Performance
  ( sumAndLength
  , meanInt
  , histogram
  , sumSquaresEven
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

-- | 嚴格累加器:tuple 的欄位是惰性的,會堆 thunk;
-- 自訂嚴格型別才是 fold 累加的標準寫法。(送你,拿去用)
data SL = SL !Int !Int

-- | 一趟同時算總和與長度,O(1) 空間。
-- 提示:foldl' + SL。(sum xs, length xs) 走兩趟還會抓住 list 頭,不及格。
sumAndLength :: [Int] -> (Int, Int)
sumAndLength = undefined

-- | 平均值(空 list 回 0),建立在 sumAndLength 上。
meanInt :: [Int] -> Double
meanInt = undefined

-- | 詞頻表。一定要 Data.Map.Strict(本模組已幫你 import 對),
-- 提示:foldl' + Map.insertWith (+)。
histogram :: [Text] -> Map Text Int
histogram = undefined

-- | 1..n 中偶數的平方和。用管線風格寫
-- (枚舉 → 過濾 → 映射 → 摺疊,或 list comprehension + foldl'),
-- -O1 下 GHC 的 list fusion 會熔成一個迴圈,不配置中間 list。
sumSquaresEven :: Int -> Int
sumSquaresEven = undefined
