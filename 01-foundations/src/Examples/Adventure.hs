{-# LANGUAGE NoFieldSelectors #-}

-- | 第 4、5 章的示範程式:用一個小小的冒險遊戲領域,
-- 展示 ADT、record(現代寫法)、deriving strategies 與 typeclass。
--
-- 在 ghci 裡玩玩看:
--
-- > cabal repl level01-foundations
-- > ghci> import Examples.Adventure
-- > ghci> sampleHero.hp
-- > ghci> takeDamage 30 sampleHero
module Examples.Adventure
  ( Element (..)
  , Monster (..)
  , Player (..)
  , sampleHero
  , takeDamage
  , describeMonster
  ) where

import Data.Text (Text)
import Data.Text qualified as T

-- 單純的列舉型 ADT:deriving 一律標明 strategy(2026 慣例)
data Element = Fire | Ice | Lightning
  deriving stock (Eq, Show, Enum, Bounded)

-- 帶資料的 sum type
data Monster
  = Slime Int              -- ^ 史萊姆,帶 HP
  | Dragon Element Int     -- ^ 龍,帶屬性與 HP
  deriving stock (Eq, Show)

-- 現代 record:NoFieldSelectors 關掉頂層 selector 函式,
-- 改用 OverloadedRecordDot 的 person.field 語法存取。
data Player = Player
  { name :: Text
  , hp :: Int
  , maxHp :: Int
  , gold :: Int
  }
  deriving stock (Eq, Show)

sampleHero :: Player
sampleHero = Player {name = "Hero", hp = 100, maxHp = 100, gold = 50}

-- record update 語法照常可用;HP 不會低於 0(total 的思考習慣)
takeDamage :: Int -> Player -> Player
takeDamage dmg p = p {hp = max 0 (p.hp - dmg)}

describeMonster :: Monster -> Text
describeMonster = \case
  Slime hp -> "一隻史萊姆(HP " <> tshow hp <> ")"
  Dragon el hp -> "一條" <> elementName el <> "龍(HP " <> tshow hp <> ")"
  where
    elementName = \case
      Fire -> "火"
      Ice -> "冰"
      Lightning -> "雷"

tshow :: Show a => a -> Text
tshow = T.pack . show
