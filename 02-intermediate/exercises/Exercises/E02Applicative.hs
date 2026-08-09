{-# LANGUAGE NoFieldSelectors #-}

-- | 第 2 章習題:Applicative
module Exercises.E02Applicative
  ( Buff (..)
  , liftPair
  , Hero (..)
  , validateName
  , validateHp
  , mkHero
  ) where

import Data.Text (Text)
import Data.Text qualified as T

-- | 增益效果:可能沒有,可能有一個。
data Buff a = NoBuff | Buff a
  deriving stock (Eq, Show)

-- Functor 送你(第 1 章複習)
instance Functor Buff where
  fmap _ NoBuff = NoBuff
  fmap f (Buff x) = Buff (f x)

-- | 實作 Applicative:
-- pure 把值放進最小的上下文;
-- <*> 把「裝在 Buff 裡的函式」套用到「裝在 Buff 裡的值」,
-- 任何一邊是 NoBuff 結果就是 NoBuff。
instance Applicative Buff where
  pure = undefined
  (<*>) = undefined

-- | 把兩個「同上下文的值」配成一對。
-- 對任何 Applicative 都成立 —— 提示:liftA2(Prelude 已有)
-- 或 (,) <$> fa <*> fb。
--
-- >>> liftPair (Just 1) (Just "x")
-- Just (1,"x")
liftPair :: Applicative f => f a -> f b -> f (a, b)
liftPair fa fb = undefined

data Hero = Hero
  { name :: Text
  , hp :: Int
  }
  deriving stock (Eq, Show)

-- | 名字去掉頭尾空白後不能是空字串,
-- 合法回 Right(去空白後的名字),否則 Left "名字不能為空"。
validateName :: Text -> Either Text Text
validateName t = undefined

-- | HP 必須在 1..100,否則 Left "HP 必須在 1..100"。
validateHp :: Int -> Either Text Int
validateHp n = undefined

-- | 用上面兩個驗證函式組出 Hero。
-- 套路:Hero <$> validateName n <*> validateHp h
-- (Either 是 Applicative:遇到第一個 Left 就停)
mkHero :: Text -> Int -> Either Text Hero
mkHero n h = undefined
