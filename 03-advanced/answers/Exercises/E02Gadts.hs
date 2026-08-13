-- | 第 2 章習題:GADTs(參考解答)
module Exercises.E02Gadts
  ( Expr (..)
  , eval
  , render
  , size
  ) where

import Data.Text (Text)
import Data.Text qualified as T

-- | 傷害公式 DSL。型別參數 a =「這個運算式算出什麼」。
-- 型別錯的公式(如 Add 一個 Bool)根本建構不出來。
data Expr a where
  IntE  :: Int -> Expr Int
  BoolE :: Bool -> Expr Bool
  Add   :: Expr Int -> Expr Int -> Expr Int
  Mul   :: Expr Int -> Expr Int -> Expr Int
  Leq   :: Expr Int -> Expr Int -> Expr Bool
  If    :: Expr Bool -> Expr a -> Expr a -> Expr a

-- | 解譯器。match 到建構子就免費得到型別等式
-- (IntE 分支裡 GHC 知道 a ~ Int),所以不需要 Either、不需要檢查。
eval :: Expr a -> a
eval (IntE n) = n
eval (BoolE b) = b
eval (Add x y) = eval x + eval y
eval (Mul x y) = eval x * eval y
eval (Leq x y) = eval x <= eval y
eval (If c t e) = if eval c then eval t else eval e

-- | 輸出可讀的公式字串:
--
-- * IntE 3            → "3"
-- * BoolE True/False  → "true" / "false"
-- * Add/Mul/Leq       → "(x + y)"、"(x * y)"、"(x <= y)"
-- * If c t e          → "if c then t else e"(不加括號)
render :: Expr a -> Text
render (IntE n) = T.pack (show n)
render (BoolE b) = if b then "true" else "false"
render (Add x y) = "(" <> render x <> " + " <> render y <> ")"
render (Mul x y) = "(" <> render x <> " * " <> render y <> ")"
render (Leq x y) = "(" <> render x <> " <= " <> render y <> ")"
render (If c t e) = "if " <> render c <> " then " <> render t <> " else " <> render e

-- | 節點總數(每個建構子算 1)。
-- 對 GADT 做「不在乎 a」的遞迴,和普通 ADT 一樣自然。
size :: Expr a -> Int
size (IntE _) = 1
size (BoolE _) = 1
size (Add x y) = 1 + size x + size y
size (Mul x y) = 1 + size x + size y
size (Leq x y) = 1 + size x + size y
size (If c t e) = 1 + size c + size t + size e
