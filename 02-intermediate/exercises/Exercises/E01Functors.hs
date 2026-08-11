-- | 第 1 章習題:Functor
--
-- 把 undefined 換成實作 → cabal test level02-intermediate
module Exercises.E01Functors
  ( Chest (..)
  , Pair (..)
  , buffAll
  ) where

-- | 寶箱:可能是空的,可能裝一個東西(就是自製的 Maybe)。
data Chest a = EmptyChest | Chest a
  deriving stock (Eq, Show)

-- | 為 Chest 實作 Functor。
-- law:fmap id = id、fmap (f . g) = fmap f . fmap g(測試會抽查)
instance Functor Chest where
  fmap _ EmptyChest = EmptyChest
  fmap f (Chest x) = Chest (f x)

-- | 一對同型別的值(例如雙持武器)。
data Pair a = Pair a a
  deriving stock (Eq, Show)

-- | 為 Pair 實作 Functor:兩個位置都要套用。
instance Functor Pair where
  fmap f (Pair a b) = Pair (f a) (f b)

-- | 對「任何 Functor 容器」裡的每個數值 +n。
-- 同一份程式碼要能用在 []、Maybe、Chest、Pair……
-- 這就是抽象的力量:實作只有一行。
--
-- >>> buffAll 5 [1, 2]
-- [6,7]
-- >>> buffAll 5 (Just 10)
-- Just 15
buffAll :: Functor f => Int -> f Int -> f Int
buffAll n xs = fmap (+n) xs
