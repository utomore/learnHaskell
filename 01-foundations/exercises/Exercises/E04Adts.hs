{-# LANGUAGE NoFieldSelectors #-}

-- | 第 4 章習題:代數資料型別(ADT)與現代 record
--
-- 型別定義都給好了,請實作函式。
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

import Data.Text (Text, pack)

data Element = Fire | Ice | Lightning
  deriving stock (Eq, Show)

-- | 屬性克制:Fire 打 Ice、Ice 打 Lightning、Lightning 打 Fire
-- 都是 2.0 倍;同屬性 0.5 倍;其他組合 1.0 倍。
-- 提示:對 tuple 做 pattern matching → case (atk, def) of ...
effectiveness :: Element -> Element -> Double
effectiveness atk def = case (atk, def) of
  (Fire, Ice) -> 2.0
  (Ice, Lightning) -> 2.0
  (Lightning, Fire) -> 2.0
  (Fire, Fire) -> 0.5
  (Ice, Ice) -> 0.5
  (Lightning, Lightning) -> 0.5
  _ -> 1.0

data Shape
  = Circle Double          -- ^ 半徑
  | Rect Double Double     -- ^ 寬、高
  deriving stock (Eq, Show)

-- | 面積(圓面積用 pi)。
area :: Shape -> Double
area shape = case shape of
  Circle radius -> radius * radius * pi
  Rect w h -> w * h

-- 現代 record:NoFieldSelectors + OverloadedRecordDot(p.hp)
data Player = Player
  { name :: Text
  , hp :: Int
  , maxHp :: Int
  }
  deriving stock (Eq, Show)

-- | 補血 n 點,但不能超過 maxHp。用 record update 語法 p {hp = ...}。
heal :: Int -> Player -> Player
heal n p = p {hp = min p.maxHp (p.hp + n)}

-- | 回傳 "<名字> (HP <目前>/<最大>)",例如 "Hero (HP 80/100)"。
-- 提示:Data.Text.pack . show 把數字轉 Text,用 <> 串接。
describePlayer :: Player -> Text
describePlayer p =
  p.name <> " (HP " <> tshow p.hp <> "/" <> tshow p.maxHp <> ")"
  where
    tshow = Data.Text.pack . show

-- 遞迴 ADT:算式樹(遊戲裡的傷害公式引擎就是這樣做的)
data Expr
  = Lit Int
  | Add Expr Expr
  | Mul Expr Expr
  | Neg Expr
  deriving stock (Eq, Show)

-- | 遞迴求值。
--
-- >>> eval (Add (Lit 1) (Mul (Lit 2) (Lit 3)))
-- 7
eval :: Expr -> Int
eval = \case
  Lit a -> a
  Add x y -> eval x + eval y
  Mul a b -> eval a * eval b
  Neg a -> negate (eval a)
