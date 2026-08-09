-- | 第 5 章習題:惰性求值 —— 什麼時候要嚴格、什麼時候要惰性
module Exercises.E05Laziness
  ( Acc (..)
  , average
  , firstNegative
  , takeUntilBudget
  ) where

-- | (送你)嚴格的累加器:兩個欄位都有 bang(!),
-- 每一步 fold 都會立刻算,不堆 thunk。
data Acc = Acc !Int !Int   -- 總和、個數
  deriving stock (Eq, Show)

-- | 一趟走完算平均:用 foldl' 配上面的 Acc 同時累積總和與個數,
-- 空清單回 Nothing。測試會餵一百萬個元素 ——
-- 用惰性 tuple 當累加器的版本會堆 thunk,這就是要 Acc 的原因。
average :: [Int] -> Maybe Double
average xs = undefined

-- | 找出第一個負數。
-- 測試會餵「無限長」的 list —— 只要你用 find 或惰性遞迴,
-- 就只會走訪到第一個負數為止。這是惰性的紅利:
-- 「搜尋無限資料」不用特殊 API。
-- 提示:Data.List 的 find,或自己遞迴。
firstNegative :: [Int] -> Maybe Int
firstNegative xs = undefined

-- | 依序拿取項目,直到預算不夠買下一項為止。
-- 也必須對無限 list 有效(測試:takeUntilBudget 10 (repeat 3) = [3,3,3])
--
-- >>> takeUntilBudget 5 [2, 2, 2, 2]
-- [2,2]
--
-- 提示:遞迴,產出一個元素後才遞迴下去(這就是惰性產出)。
takeUntilBudget :: Int -> [Int] -> [Int]
takeUntilBudget budget costs = undefined
