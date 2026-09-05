-- | 第 5 章習題(下):用真套件 optics-core(參考解答)
--
-- 第 5 章上半手刻了 lens;這裡用 2026 推薦的 optics 套件做同一件事,
-- 再加上手刻版沒做的 Traversal 與 Prism。
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

-- 基本 lens:optics 的 lens 函式簽名和你手刻的一模一樣。

statsL :: Lens' Hero Stats
statsL = lens (.stats) (\h s -> h {stats = s})

hpL :: Lens' Stats Int
hpL = lens (.hp) (\s v -> s {hp = v})

priceL :: Lens' Item Int
priceL = lens (.price) (\i v -> i {price = v})

bagL :: Lens' Hero [Item]
bagL = lens (.bag) (\h b -> h {bag = b})

weaponL :: Lens' Hero Slot
weaponL = lens (.weapon) (\h w -> h {weapon = w})

-- | Prism:聚焦 sum type 的一個分支。
-- prism' 建構子 拆解器;拆不到就 Nothing。
equippedP :: Prism' Slot Item
equippedP = prism' Equipped $ \case
  Equipped i -> Just i
  Bare -> Nothing

-- | 合成用 %(不是 .),方向仍然由外而內。
heroHp :: Lens' Hero Int
heroHp = statsL % hpL

-- | Traversal:0..n 個焦點。traversed 會走進 list 的每個元素。
bagPrices :: Traversal' Hero Int
bagPrices = bagL % traversed % priceL

takeDamage :: Int -> Hero -> Hero
takeDamage n = over heroHp (max 0 . subtract n)

-- | 全背包打折:pct 是百分比(10 = 打九折),用整數除法。
discountAll :: Int -> Hero -> Hero
discountAll pct = over bagPrices (\p -> p - p * pct `div` 100)

-- | 背包總價:對 traversal 用 sumOf。
bagValue :: Hero -> Int
bagValue = sumOf bagPrices

-- | 武器名稱:lens % prism % getter,用 preview 讀(可能沒有)。
weaponName :: Hero -> Maybe Text
weaponName = preview (weaponL % equippedP % to (.label))
