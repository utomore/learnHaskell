{-# LANGUAGE DerivingVia #-}

-- | 第 4 章習題:DerivingVia
--
-- 這章的習題形式不同:主要工作是「刪掉手寫 instance,換成 deriving via」。
-- 完成後 → cabal test level03-advanced
module Exercises.E04DerivingVia
  ( Gold (..)
  , HighScore (..)
  , Capped (..)
  , Rage (..)
  , totalLoot
  , bestScore
  ) where

import Data.Semigroup (Max (..), Sum (..))

-- | 金幣:合併 = 相加。
--
-- TODO:刪掉下面兩個手寫 instance,改成在 deriving stock 下面加一行
--   deriving (Semigroup, Monoid) via Sum Int
newtype Gold = Gold Int
  deriving stock (Eq, Show)

instance Semigroup Gold where
  (<>) = undefined

instance Monoid Gold where
  mempty = undefined

-- | 最高分:合併 = 取大。
--
-- TODO:同上,改成 via Max Int(Max Int 的 mempty 是 minBound)。
newtype HighScore = HighScore Int
  deriving stock (Eq, Show)

instance Semigroup HighScore where
  (<>) = undefined

instance Monoid HighScore where
  mempty = undefined

-- | 自訂 via 載體:「相加但封頂 100」。
-- 這兩個 instance 請實作(mempty = Capped 0;<> = 相加後 min 100)。
newtype Capped = Capped Int
  deriving stock (Eq, Show)

instance Semigroup Capped where
  (<>) = undefined

instance Monoid Capped where
  mempty = undefined

-- | 怒氣值:0..100,累積封頂 → 直接借 Capped(這行送你,當範例)。
newtype Rage = Rage Int
  deriving stock (Eq, Show)
  deriving (Semigroup, Monoid) via Capped

-- | 撿到的金幣全部加總(提示:有 Monoid 之後就是 mconcat)。
totalLoot :: [Gold] -> Gold
totalLoot = undefined

-- | 歷史最高分。
bestScore :: [HighScore] -> HighScore
bestScore = undefined
