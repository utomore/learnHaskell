{-# LANGUAGE DerivingVia #-}

-- | 第 4 章習題:DerivingVia(參考解答)
module Exercises.E04DerivingVia
  ( Gold (..)
  , HighScore (..)
  , Capped (..)
  , Rage (..)
  , totalLoot
  , bestScore
  ) where

import Data.Semigroup (Max (..), Sum (..))

-- | 金幣:合併 = 相加 → 直接借 Sum Int 的 instance。
newtype Gold = Gold Int
  deriving stock (Eq, Show)
  deriving (Semigroup, Monoid) via Sum Int

-- | 最高分:合併 = 取大 → 借 Max Int。
newtype HighScore = HighScore Int
  deriving stock (Eq, Show)
  deriving (Semigroup, Monoid) via Max Int

-- | 自訂 via 載體:「相加但封頂 100」。
-- instance 邏輯(和它的 laws)只寫這一次。
newtype Capped = Capped Int
  deriving stock (Eq, Show)

instance Semigroup Capped where
  Capped a <> Capped b = Capped (min 100 (a + b))

instance Monoid Capped where
  mempty = Capped 0

-- | 怒氣值:0..100,累積封頂 → 借 Capped。
newtype Rage = Rage Int
  deriving stock (Eq, Show)
  deriving (Semigroup, Monoid) via Capped

-- | 撿到的金幣全部加總(提示:有 Monoid 之後就是 mconcat)。
totalLoot :: [Gold] -> Gold
totalLoot = mconcat

-- | 歷史最高分。
bestScore :: [HighScore] -> HighScore
bestScore = mconcat
