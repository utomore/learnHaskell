{-# LANGUAGE NoFieldSelectors #-}

-- | 第 4 章參考解答
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

openAll :: [Maybe a] -> Maybe [a]
openAll = sequenceA

readInt :: Text -> Maybe Int
readInt t = case TR.signed TR.decimal (T.strip t) of
  Right (n, rest) | T.null rest -> Just n
  _ -> Nothing

parseAllInts :: [Text] -> Maybe [Int]
parseAllInts = traverse readInt

data Adventurer = Adventurer
  { name :: Text
  , hp :: Int
  , gold :: Int
  }
  deriving stock (Eq, Show)

partyGold :: [Adventurer] -> Int
partyGold = getSum . foldMap (Sum . (.gold))

allAlive :: [Adventurer] -> Bool
allAlive = all ((> 0) . (.hp))
