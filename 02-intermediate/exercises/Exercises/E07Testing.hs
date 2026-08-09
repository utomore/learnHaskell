-- | 第 7 章習題:為 property-based testing 而寫的函式
--
-- 這章的重點在測試端:test/Main.hs 用 hedgehog 對這兩個函式
-- 做「性質測試」—— 不是驗證單一輸入輸出,而是驗證對隨機輸入
-- 恆成立的不變量。實作完去讀測試怎麼寫的。
module Exercises.E07Testing
  ( insertSorted
  , myReplicate
  ) where

-- | 把 x 插入「已排序」的 list,結果仍然要排好序。
-- 性質:輸出有序、長度 +1、x 在輸出裡。
insertSorted :: Int -> [Int] -> [Int]
insertSorted x sorted = undefined

-- | 自己實作 replicate。
-- 性質:長度 = max 0 n、每個元素都等於 x。
myReplicate :: Int -> a -> [a]
myReplicate n x = undefined
