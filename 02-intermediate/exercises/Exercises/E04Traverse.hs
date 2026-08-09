{-# LANGUAGE NoFieldSelectors #-}

-- | 第 4 章習題:Foldable 與 Traversable
module Exercises.E04Traverse
  ( openAll
  , readInt
  , parseAllInts
  , Adventurer (..)
  , partyGold
  , allAlive
  ) where

import Data.Monoid (Sum (..))
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Read qualified as TR

-- | 開所有寶箱:全部都有東西才算成功,
-- 有一箱是 Nothing 整趟就是 Nothing。
-- 提示:這就是 sequenceA。
--
-- >>> openAll [Just 1, Just 2]
-- Just [1,2]
-- >>> openAll [Just 1, Nothing]
-- Nothing
openAll :: [Maybe a] -> Maybe [a]
openAll chests = undefined

-- | (送你)Text 轉 Int,用 text 套件內建的 reader。
readInt :: Text -> Maybe Int
readInt t = case TR.signed TR.decimal (T.strip t) of
  Right (n, rest) | T.null rest -> Just n
  _ -> Nothing

-- | 解析一排數字,任何一個失敗就整體失敗。
-- 提示:traverse readInt(traverse = map + sequenceA 一次做完)
parseAllInts :: [Text] -> Maybe [Int]
parseAllInts ts = undefined

data Adventurer = Adventurer
  { name :: Text
  , hp :: Int
  , gold :: Int
  }
  deriving stock (Eq, Show)

-- | 全隊金幣總和。
-- 提示:foldMap (Sum . (.gold)) 之後 getSum,
-- 或者直接 sum(sum 本身就是用 Foldable 定義的)。
partyGold :: [Adventurer] -> Int
partyGold party = undefined

-- | 全隊都活著(HP > 0)嗎?提示:all
allAlive :: [Adventurer] -> Bool
allAlive party = undefined
