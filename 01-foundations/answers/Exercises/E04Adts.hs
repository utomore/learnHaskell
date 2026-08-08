{-# LANGUAGE NoFieldSelectors #-}

-- | 第 4 章參考解答
module Exercises.E04Adts
  ( Element (..)
  , effectiveness
  , Shape (..)
  , area
  , Player (..)
  , heal
  , describePlayer
  , Expr (..)
  , eval
  ) where

import Data.Text (Text)
import Data.Text qualified as T

data Element = Fire | Ice | Lightning
  deriving stock (Eq, Show)

effectiveness :: Element -> Element -> Double
effectiveness atk def = case (atk, def) of
  (Fire, Ice) -> 2.0
  (Ice, Lightning) -> 2.0
  (Lightning, Fire) -> 2.0
  _ | atk == def -> 0.5
  _ -> 1.0

data Shape
  = Circle Double
  | Rect Double Double
  deriving stock (Eq, Show)

area :: Shape -> Double
area = \case
  Circle r -> pi * r * r
  Rect w h -> w * h

data Player = Player
  { name :: Text
  , hp :: Int
  , maxHp :: Int
  }
  deriving stock (Eq, Show)

heal :: Int -> Player -> Player
heal n p = p {hp = min p.maxHp (p.hp + n)}

describePlayer :: Player -> Text
describePlayer p =
  p.name <> " (HP " <> tshow p.hp <> "/" <> tshow p.maxHp <> ")"
  where
    tshow = T.pack . show

data Expr
  = Lit Int
  | Add Expr Expr
  | Mul Expr Expr
  | Neg Expr
  deriving stock (Eq, Show)

eval :: Expr -> Int
eval = \case
  Lit n -> n
  Add a b -> eval a + eval b
  Mul a b -> eval a * eval b
  Neg a -> negate (eval a)
