-- | 第 7 章參考解答
module Exercises.E07IO
  ( numberLines
  , parseKeyValue
  , parseConfig
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as T

numberLines :: Text -> Text
numberLines t =
  T.unlines
    [ T.pack (show i) <> ": " <> line
    | (i, line) <- zip [(1 :: Int) ..] (T.lines t)
    ]

parseKeyValue :: Text -> Maybe (Text, Text)
parseKeyValue line =
  case T.breakOn "=" line of
    (_, "") -> Nothing
    (key, rest) -> Just (T.strip key, T.strip (T.drop 1 rest))

parseConfig :: Text -> Map Text Text
parseConfig = Map.fromList . mapMaybe parseKeyValue . T.lines
