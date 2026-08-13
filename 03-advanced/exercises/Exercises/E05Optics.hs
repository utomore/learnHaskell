-- | 第 5 章習題:手刻迷你 lens 庫
--
-- 把 undefined 換成實作 → cabal test level03-advanced
module Exercises.E05Optics
  ( Lens'
  , lens
  , view
  , over
  , set
  , Stats (..)
  , Hero (..)
  , statsL
  , hpL
  , heroHpL
  , takeDamage
  ) where

import Data.Functor.Const (Const (..))
import Data.Functor.Identity (Identity (..))
import Data.Text (Text)

-- | van Laarhoven lens:「聚焦 s 裡的一個 a」。
-- 它只是一個函式,所以 lens 合成 = 函式合成(.)。
type Lens' s a = forall f. Functor f => (a -> f a) -> s -> f s

-- | 用 getter + setter 做一個 lens。
-- 提示:對焦點套 f,再用 <$> 把「新的 a」放回 s。
--
-- (骨架註:rank-2 型別不能整個 = undefined,先接參數再 undefined。)
lens :: (s -> a) -> (s -> a -> s) -> Lens' s a
lens _get _put = undefined

-- | 讀:用 Const 當 Functor —— 假裝要改,其實把焦點值偷渡出來。
-- 提示:getConst (l Const s)。
view :: Lens' s a -> s -> a
view _l = undefined

-- | 改:用 Identity 當 Functor —— 真的套用函式。
over :: Lens' s a -> (a -> a) -> s -> s
over _l = undefined

-- | 設值:over 的特例。
set :: Lens' s a -> a -> s -> s
set _l = undefined

data Stats = Stats
  { hp :: Int
  , mp :: Int
  }
  deriving stock (Eq, Show)

data Hero = Hero
  { name :: Text
  , stats :: Stats
  }
  deriving stock (Eq, Show)

-- | 聚焦 Hero 的 stats 欄位(用 lens 函式做)。
statsL :: Lens' Hero Stats
statsL = undefined

-- | 聚焦 Stats 的 hp 欄位。
hpL :: Lens' Stats Int
hpL = undefined

-- | 合成:一路聚焦到 Hero 的 hp。
-- 提示:一個 (.) 就好,方向和 record dot 一致(由外而內)。
heroHpL :: Lens' Hero Int
heroHpL = undefined

-- | 扣血,不低於 0 —— 用 over + heroHpL,一行。
takeDamage :: Int -> Hero -> Hero
takeDamage = undefined
