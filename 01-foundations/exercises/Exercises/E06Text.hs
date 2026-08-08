-- | 第 6 章習題:Text(2026 的預設字串型別)
--
-- 常用 API 都在 Data.Text(此處已 qualified import 成 T)。
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

-- | 全部轉大寫並加上 "!"。
--
-- >>> shout "hello"
-- "HELLO!"
shout :: Text -> Text
shout t = undefined

-- | 數單字數。提示:T.words
countWords :: Text -> Int
countWords t = undefined

-- | 轉成網址 slug:全小寫、空白換成 '-'、
-- 只保留英數字與 '-'。
--
-- >>> slugify "Hello World! 123"
-- "hello-world-123"
--
-- 提示:T.toLower、T.map 或 T.words + T.intercalate、T.filter
slugify :: Text -> Text
slugify t = undefined

-- | 戰鬥訊息:"<攻擊者> 對 <目標> 造成 <n> 點傷害"
--
-- >>> attackMessage "Hero" "Slime" 12
-- "Hero \23545 ... "  -- (中文訊息,見測試)
attackMessage :: Text -> Text -> Int -> Text
attackMessage attacker target dmg = undefined

-- | 統計每個單字出現次數。
-- 提示:Map.fromListWith (+) 搭配 [(w, 1) | w <- ...]
wordFreq :: Text -> Map Text Int
wordFreq t = undefined
