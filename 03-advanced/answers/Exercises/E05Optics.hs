-- | 第 5 章習題:手刻迷你 lens 庫(參考解答)
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
lens :: (s -> a) -> (s -> a -> s) -> Lens' s a
lens get put f s = put s <$> f (get s)

-- | 讀:用 Const 當 Functor —— 假裝要改,其實把焦點值偷渡出來。
view :: Lens' s a -> s -> a
view l s = getConst (l Const s)

-- | 改:用 Identity 當 Functor —— 真的套用函式。
over :: Lens' s a -> (a -> a) -> s -> s
over l g s = runIdentity (l (Identity . g) s)

-- | 設值:over 的特例。
set :: Lens' s a -> a -> s -> s
set l a = over l (const a)

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

-- | 聚焦 Hero 的 stats 欄位。
statsL :: Lens' Hero Stats
statsL = lens (.stats) (\h s -> h {stats = s})

-- | 聚焦 Stats 的 hp 欄位。
hpL :: Lens' Stats Int
hpL = lens (.hp) (\st h -> st {hp = h})

-- | 合成:一路聚焦到 Hero 的 hp。方向和 record dot 一致(由外而內)。
heroHpL :: Lens' Hero Int
heroHpL = statsL . hpL

-- | 扣血,不低於 0 —— 巢狀更新一行搞定。
takeDamage :: Int -> Hero -> Hero
takeDamage n = over heroHpL (max 0 . subtract n)
