-- | 第 7 章習題:效能調校(參考解答)
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
-- 自訂嚴格型別才是 fold 累加的標準寫法。
data SL = SL !Int !Int

-- | 一趟同時算總和與長度,O(1) 空間。
-- (sum xs, length xs) 走兩趟還會抓住 list 頭 —— 反面教材。
sumAndLength :: [Int] -> (Int, Int)
sumAndLength xs = case foldl' step (SL 0 0) xs of
  SL s n -> (s, n)
  where
    step (SL s n) x = SL (s + x) (n + 1)

-- | 平均值(空 list 回 0),建立在 sumAndLength 上。
meanInt :: [Int] -> Double
meanInt xs = case sumAndLength xs of
  (_, 0) -> 0
  (s, n) -> fromIntegral s / fromIntegral n

-- | 詞頻表:一定要 Data.Map.Strict,lazy Map 的值會堆 1+1+1... 的 thunk 鏈。
histogram :: [Text] -> Map Text Int
histogram = foldl' (\m w -> Map.insertWith (+) w 1 m) Map.empty

-- | 1..n 中偶數的平方和。管線風格(枚舉 → 過濾 → 映射 → 摺疊),
-- -O1 下 GHC 的 list fusion 會熔成一個迴圈,不配置中間 list。
sumSquaresEven :: Int -> Int
sumSquaresEven n = foldl' (+) 0 [x * x | x <- [1 .. n], even x]
