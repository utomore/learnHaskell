{-# LANGUAGE TypeFamilies #-}

-- | 第 3 章習題:Type families
--
-- 把 undefined 換成實作 → cabal test level03-advanced
module Exercises.E03TypeFamilies
  ( Container (..)
  , fromListC
  ) where

import Data.IntSet (IntSet)
import Data.IntSet qualified as IntSet
import Data.Kind (Type)
import Data.Text (Text)
import Data.Text qualified as T

-- | 可插入元素的容器。Elem 是 associated type:
-- 每個 instance 自己宣告「我的元素是什麼型別」,
-- 所以沒有型別參數的 IntSet、Text 也裝得進來。
class Container c where
  type Elem c :: Type
  emptyC :: c
  insertC :: Elem c -> c -> c
  toListC :: c -> [Elem c]

-- 型別層級的部分(type Elem ...)已經給你,實作方法即可。

instance Container [a] where
  type Elem [a] = a
  emptyC = undefined
  insertC = undefined
  toListC = undefined

instance Container IntSet where
  type Elem IntSet = Int
  emptyC = undefined
  insertC = undefined -- 提示:IntSet.insert
  toListC = undefined

instance Container Text where
  type Elem Text = Char
  emptyC = undefined
  insertC = undefined -- 提示:T.cons
  toListC = undefined

-- | 泛型建構:同一份程式碼,回傳型別決定用哪個容器。
-- 提示:foldr + 上面兩個方法,一行。
--
-- >>> fromListC [3, 1, 2, 3] :: IntSet   -- 自動去重排序
-- fromList [1,2,3]
fromListC :: Container c => [Elem c] -> c
fromListC = undefined
