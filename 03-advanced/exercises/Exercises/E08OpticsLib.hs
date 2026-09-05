-- | 第 5 章習題(下):用真套件 optics-core
--
-- 第 5 章上半手刻了 lens;這裡用 2026 推薦的 optics 套件做同一件事,
-- 再加上手刻版沒做的 Traversal 與 Prism。
-- 把 undefined 換成實作 → cabal test level03-advanced
module Exercises.E08OpticsLib
  ( Item (..)
  , Slot (..)
  , Stats (..)
  , Hero (..)
  , statsL
  , hpL
  , priceL
  , bagL
  , weaponL
  , equippedP
  , heroHp
  , bagPrices
  , takeDamage
  , discountAll
  , bagValue
  , weaponName
  ) where

import Data.Text (Text)
import Optics.Core

data Item = Item
  { label :: Text
  , price :: Int
  }
  deriving stock (Eq, Show)

-- | 武器槽:可能是空的。
-- (建構子不叫 Empty,因為 Optics.Core 匯出了一個同名的 class。)
data Slot = Bare | Equipped Item
  deriving stock (Eq, Show)

data Stats = Stats
  { hp :: Int
  , mp :: Int
  }
  deriving stock (Eq, Show)

data Hero = Hero
  { name :: Text
  , stats :: Stats
  , bag :: [Item]
  , weapon :: Slot
  }
  deriving stock (Eq, Show)

-- 基本 lens:optics 的 lens 函式簽名和你手刻的一模一樣:
--   lens :: (s -> a) -> (s -> a -> s) -> Lens' s a

statsL :: Lens' Hero Stats
statsL = undefined

hpL :: Lens' Stats Int
hpL = undefined

priceL :: Lens' Item Int
priceL = undefined

bagL :: Lens' Hero [Item]
bagL = undefined

weaponL :: Lens' Hero Slot
weaponL = undefined

-- | Prism:聚焦 sum type 的一個分支。
-- 提示:prism' Equipped (\case Equipped i -> Just i; Bare -> Nothing)
equippedP :: Prism' Slot Item
equippedP = undefined

-- | 合成用 %(不是 .),方向仍然由外而內:statsL % hpL。
heroHp :: Lens' Hero Int
heroHp = undefined

-- | Traversal:0..n 個焦點。提示:bagL % traversed % priceL。
bagPrices :: Traversal' Hero Int
bagPrices = undefined

-- | 扣血不低於 0(和第 5 章上半一樣,換成 optics 的 over)。
takeDamage :: Int -> Hero -> Hero
takeDamage = undefined

-- | 全背包打折:pct 是百分比(10 = 打九折),每件 p 變成 p - p * pct `div` 100。
-- 提示:over bagPrices。
discountAll :: Int -> Hero -> Hero
discountAll = undefined

-- | 背包總價。提示:sumOf bagPrices。
bagValue :: Hero -> Int
bagValue = undefined

-- | 武器名稱(沒裝備就 Nothing)。
-- 提示:preview (weaponL % equippedP % to (.label))。
weaponName :: Hero -> Maybe Text
weaponName = undefined
