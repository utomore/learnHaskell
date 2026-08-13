{-# LANGUAGE TypeFamilies #-}

-- | 第 3 章習題:Type families(參考解答)
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

instance Container [a] where
  type Elem [a] = a
  emptyC = []
  insertC = (:)
  toListC = id

instance Container IntSet where
  type Elem IntSet = Int
  emptyC = IntSet.empty
  insertC = IntSet.insert
  toListC = IntSet.toList

instance Container Text where
  type Elem Text = Char
  emptyC = T.empty
  insertC = T.cons
  toListC = T.unpack

-- | 泛型建構:同一份程式碼,回傳型別決定用哪個容器。
--
-- >>> fromListC [3, 1, 2, 3] :: IntSet   -- 自動去重排序
-- fromList [1,2,3]
fromListC :: Container c => [Elem c] -> c
fromListC = foldr insertC emptyC
