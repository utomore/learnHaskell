-- | 第 3 章參考解答
module Exercises.E03Monads
  ( andThen
  , weaponDamage
  , allPairs
  , avgDamage
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

andThen :: Maybe a -> (a -> Maybe b) -> Maybe b
andThen Nothing _ = Nothing
andThen (Just x) f = f x

weaponDamage :: Map Text Text -> Map Text Int -> Text -> Maybe Int
weaponDamage equips stats hero = do
  weapon <- Map.lookup hero equips
  Map.lookup weapon stats

allPairs :: [a] -> [b] -> [(a, b)]
allPairs xs ys = do
  x <- xs
  y <- ys
  pure (x, y)

avgDamage :: [Int] -> Maybe Double
avgDamage [] = Nothing
avgDamage hits =
  Just (fromIntegral (sum hits) / fromIntegral (length hits))
