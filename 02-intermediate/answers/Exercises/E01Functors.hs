-- | 第 1 章參考解答
module Exercises.E01Functors
  ( Chest (..)
  , Pair (..)
  , buffAll
  ) where

data Chest a = EmptyChest | Chest a
  deriving stock (Eq, Show)

instance Functor Chest where
  fmap _ EmptyChest = EmptyChest
  fmap f (Chest x) = Chest (f x)

data Pair a = Pair a a
  deriving stock (Eq, Show)

instance Functor Pair where
  fmap f (Pair a b) = Pair (f a) (f b)

buffAll :: Functor f => Int -> f Int -> f Int
buffAll n = fmap (+ n)
