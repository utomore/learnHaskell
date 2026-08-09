-- | 第 7 章習題:IO 與「純核心、薄 IO 殼」架構
--
-- 好的 Haskell 程式把邏輯寫成純函式,IO 只做輸入輸出。
-- 這裡的三個函式都是純的 —— 它們會被一個讀取設定檔的
-- 小程式使用(見 notes/07-io.md 的完整範例)。
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

-- | 幫每一行加上行號(從 1 開始),格式 "N: 內容"。
--
-- >>> numberLines "aa\nbb"
-- "1: aa\n2: bb\n"
--
-- 提示:T.lines、zip [1..]、T.unlines
numberLines :: Text -> Text
numberLines t =
  T.unlines
    [ T.pack (show i) <> ": " <> line
    | (i, line) <- zip [(1 :: Int) ..] (T.lines t)
    ]


-- | 解析 "key=value" 一行設定;沒有 '=' 回 Nothing。
-- 鍵與值前後的空白要去掉(T.strip)。
--
-- >>> parseKeyValue "name = Hero"
-- Just ("name","Hero")
--
-- 提示:T.breakOn "=" 會切成 ("name ", "= Hero"),
-- 再用 T.stripPrefix "=" 或 T.drop 1 處理後半。
parseKeyValue :: Text -> Maybe (Text, Text)
parseKeyValue line = 
  case T.breakOn "=" line of 
    (_, "") -> Nothing
    (key, rest) -> Just (T.strip key, T.strip (T.drop 1 rest))

-- | 解析整份設定檔:每行一個 key=value,
-- 解析失敗的行直接略過。提示:mapMaybe、Map.fromList
parseConfig :: Text -> Map Text Text
parseConfig = Map.fromList . mapMaybe parseKeyValue . T.lines
