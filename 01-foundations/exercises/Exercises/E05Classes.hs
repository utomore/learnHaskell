{-# LANGUAGE NoFieldSelectors #-}

-- | 第 5 章習題:typeclass、Semigroup/Monoid、deriving strategies
module Exercises.E05Classes
  ( Gold (..)
  , Item (..)
  , totalPrice
  , cheapest
  ) where

import Data.Text (Text)
import Data.List (minimumBy)
import Data.Ord (comparing)

-- | 金幣。newtype + deriving newtype 是 2026 標準寫法:
-- Eq/Ord/Show 直接沿用 Int 的行為。
newtype Gold = Gold Int
  deriving newtype (Eq, Ord, Show)

-- | 實作 Semigroup:兩袋金幣合併就是相加。
instance Semigroup Gold where
  Gold a <> Gold b = Gold (a+b)

-- | 實作 Monoid:空袋子是多少金幣?
instance Monoid Gold where
  mempty = Gold 0

data Item = Item
  { name :: Text
  , price :: Gold
  }
  deriving stock (Eq, Show)

-- | 全部商品的總價。提示:有了 Monoid instance,
-- 一行 foldMap (.price) 就搞定。
totalPrice :: [Item] -> Gold
totalPrice = foldMap (.price)

-- | 最便宜的商品(空清單回 Nothing)。
-- 提示:Data.List 的 sortOn 或 minimumBy;比較鍵是 (.price)。
cheapest :: [Item] -> Maybe Item
cheapest [] = Nothing
cheapest xs = Just (minimumBy (comparing (.price)) xs )
