{-# LANGUAGE NoFieldSelectors #-}

-- | 第 2 章參考解答
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

data Buff a = NoBuff | Buff a
  deriving stock (Eq, Show)

instance Functor Buff where
  fmap _ NoBuff = NoBuff
  fmap f (Buff x) = Buff (f x)

instance Applicative Buff where
  pure = Buff
  Buff f <*> Buff x = Buff (f x)
  _ <*> _ = NoBuff

liftPair :: Applicative f => f a -> f b -> f (a, b)
liftPair = liftA2 (,)

data Hero = Hero
  { name :: Text
  , hp :: Int
  }
  deriving stock (Eq, Show)

validateName :: Text -> Either Text Text
validateName t
  | T.null stripped = Left "名字不能為空"
  | otherwise = Right stripped
  where
    stripped = T.strip t

validateHp :: Int -> Either Text Int
validateHp n
  | n >= 1 && n <= 100 = Right n
  | otherwise = Left "HP 必須在 1..100"

mkHero :: Text -> Int -> Either Text Hero
mkHero n h = Hero <$> validateName n <*> validateHp h
