-- | 第 6 章參考解答
module Exercises.E06Text
  ( shout
  , countWords
  , slugify
  , attackMessage
  , wordFreq
  ) where

import Data.Char (isAlphaNum)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T

shout :: Text -> Text
shout t = T.toUpper t <> "!"

countWords :: Text -> Int
countWords = length . T.words

slugify :: Text -> Text
slugify =
  T.intercalate "-"
    . filter (not . T.null)
    . map (T.filter isAlphaNum)
    . T.words
    . T.toLower

attackMessage :: Text -> Text -> Int -> Text
attackMessage attacker target dmg =
  attacker <> " 對 " <> target <> " 造成 " <> T.pack (show dmg) <> " 點傷害"

wordFreq :: Text -> Map Text Int
wordFreq t = Map.fromListWith (+) [(w, 1) | w <- T.words t]
