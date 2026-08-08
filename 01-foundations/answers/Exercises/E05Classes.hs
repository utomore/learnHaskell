{-# LANGUAGE NoFieldSelectors #-}

-- | 第 5 章參考解答
module Exercises.E05Classes
  ( Gold (..)
  , Item (..)
  , totalPrice
  , cheapest
  ) where

import Data.List (sortOn)
import Data.Text (Text)

newtype Gold = Gold Int
  deriving newtype (Eq, Ord, Show)

instance Semigroup Gold where
  Gold a <> Gold b = Gold (a + b)

instance Monoid Gold where
  mempty = Gold 0

data Item = Item
  { name :: Text
  , price :: Gold
  }
  deriving stock (Eq, Show)

totalPrice :: [Item] -> Gold
totalPrice = foldMap (.price)

cheapest :: [Item] -> Maybe Item
cheapest items = case sortOn (.price) items of
  [] -> Nothing
  (x : _) -> Just x
