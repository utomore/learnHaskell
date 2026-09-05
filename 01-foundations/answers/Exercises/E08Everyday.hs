-- | 第 8 章習題:日常語法(參考解答)
--
-- TypeApplications、readMaybe、\case、NonEmpty、Data.Maybe 工具箱。
module Exercises.E08Everyday
  ( parseInt
  , Command (..)
  , parseCommand
  , Monster (..)
  , strongest
  , partyLeader
  , parseAll
  , describePower
  ) where

import Data.Foldable (maximumBy)
import Data.List.NonEmpty (NonEmpty, nonEmpty)
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Text (Text)
import Data.Text qualified as T
import Text.Read (readMaybe)

-- | 把文字解析成整數;前後空白要先去掉,解析失敗回 Nothing(不准用 read)。
-- 用 @Int 告訴 readMaybe 要解析成什麼型別。
parseInt :: Text -> Maybe Int
parseInt = readMaybe @Int . T.unpack . T.strip

data Command
  = Move Int
  | Attack Text
  | Rest
  | Quit
  deriving stock (Eq, Show)

-- | 解析一行指令(大小寫不分):
--
-- * "move 3"     → Move 3(數字用 parseInt,壞數字整條失敗)
-- * "attack bat" → Attack "bat"
-- * "rest"       → Rest
-- * "quit" 或 "exit" → Quit
-- * 其他         → Nothing
parseCommand :: Text -> Maybe Command
parseCommand t = case T.words (T.toLower t) of
  ["move", n] -> Move <$> parseInt n
  ["attack", who] -> Just (Attack who)
  ["rest"] -> Just Rest
  ["quit"] -> Just Quit
  ["exit"] -> Just Quit
  _ -> Nothing

data Monster = Monster
  { name :: Text
  , power :: Int
  }
  deriving stock (Eq, Show)

-- | 最強的怪。輸入是 NonEmpty,所以這個函式是 total 的:不需要 Maybe。
strongest :: NonEmpty Monster -> Monster
strongest = maximumBy (comparing (.power))

-- | 從普通 list 找隊長:空 list 回 Nothing。
-- 提示:nonEmpty :: [a] -> Maybe (NonEmpty a),再 fmap strongest。
partyLeader :: [Monster] -> Maybe Monster
partyLeader = fmap strongest . nonEmpty

-- | 解析一串文字,壞的直接丟掉。
parseAll :: [Text] -> [Int]
parseAll = mapMaybe parseInt

-- | 用 \case + guard 分級:>= 100 "傳說"、>= 50 "強敵"、其他 "雜魚"。
describePower :: Int -> Text
describePower = \case
  n
    | n >= 100 -> "傳說"
    | n >= 50 -> "強敵"
    | otherwise -> "雜魚"
