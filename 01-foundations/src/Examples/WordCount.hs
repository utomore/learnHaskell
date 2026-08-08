-- | 第 7 章示範:把「純邏輯」與 IO 分開。
-- 這個模組是純的,app/Main.hs 只負責 IO。
module Examples.WordCount
  ( Stats (..)
  , stats
  , render
  ) where

import Data.Text (Text)
import Data.Text qualified as T

data Stats = Stats
  { lineCount :: Int
  , wordCount :: Int
  , charCount :: Int
  }
  deriving stock (Eq, Show)

stats :: Text -> Stats
stats t =
  Stats
    { lineCount = length (T.lines t)
    , wordCount = length (T.words t)
    , charCount = T.length t
    }

render :: Stats -> Text
render s =
  T.unlines
    [ "行數: " <> tshow s.lineCount
    , "字數: " <> tshow s.wordCount
    , "字元: " <> tshow s.charCount
    ]
  where
    tshow = T.pack . show
