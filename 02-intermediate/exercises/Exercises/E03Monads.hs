-- | 第 3 章習題:Monad —— 會依賴前一步結果的串接
module Exercises.E03Monads
  ( andThen
  , weaponDamage
  , allPairs
  , avgDamage
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

-- | 自己實作 Maybe 的 (>>=):
-- 前一步是 Nothing 就整串放棄,否則把值餵給下一步。
-- (實作完你就知道 Maybe monad 沒有任何魔法)
andThen :: Maybe a -> (a -> Maybe b) -> Maybe b
andThen ma f = case ma of
  Nothing -> Nothing
  (Just x) -> (f x)

-- | 查兩層:英雄裝備哪把武器?那把武器攻擊力多少?
-- 任何一層查不到就 Nothing。
-- 提示:Map.lookup hero equips >>= \w -> Map.lookup w stats
-- (或用 do 記法寫)
weaponDamage
  :: Map Text Text   -- ^ 英雄 → 武器
  -> Map Text Int    -- ^ 武器 → 攻擊力
  -> Text            -- ^ 英雄名
  -> Maybe Int
weaponDamage equips stats hero = do
  weapon <- Map.lookup hero equips 
  prop_attack <- Map.lookup weapon stats
  pure (prop_attack)

  
-- | 所有組合(list monad):
--
-- >>> allPairs [1,2] "ab"
-- [(1,'a'),(1,'b'),(2,'a'),(2,'b')]
--
-- 用 do 記法寫:x <- xs; y <- ys; pure (x, y)
allPairs :: [a] -> [b] -> [(a, b)]
allPairs xs ys = do
  x <- xs
  y <- ys
  pure (x, y)

-- | 平均傷害:空清單回 Nothing(不能除以 0!)。
-- 提示:fromIntegral 把 Int 轉 Double。
avgDamage :: [Int] -> Maybe Double
avgDamage [] = Nothing
avgDamage hits = Just (fromIntegral total / fromIntegral count)
  where
    total = sum hits
    count = length hits
