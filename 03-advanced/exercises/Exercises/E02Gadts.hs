-- | 第 2 章習題:GADTs
--
-- 把 undefined 換成實作 → cabal test level03-advanced
module Exercises.E02Gadts
  ( Expr (..)
  , eval
  , render
  , size
  ) where

import Data.Text (Text)
import Data.Text qualified as T

-- | 傷害公式 DSL。型別參數 a =「這個運算式算出什麼」。
-- 型別錯的公式(如 Add 一個 Bool)根本建構不出來 —— 在 ghci 試試!
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
eval = undefined

-- | 輸出可讀的公式字串:
--
-- * IntE 3            → "3"(提示:T.pack . show)
-- * BoolE True/False  → "true" / "false"
-- * Add/Mul/Leq       → "(x + y)"、"(x * y)"、"(x <= y)"
-- * If c t e          → "if c then t else e"(不加括號)
render :: Expr a -> Text
render = undefined

-- | 節點總數(每個建構子算 1)。
-- 例:If (Leq 1 2) 3 4 → 6 個節點。
size :: Expr a -> Int
size = undefined
