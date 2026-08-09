-- | 第 6 章習題:現代錯誤處理
--
-- 領域錯誤 → Either + ADT;IO 失敗 → exception,在邊界 try 起來。
module Exercises.E06Errors
  ( Command (..)
  , GameError (..)
  , parseCommand
  , renderError
  , safeReadFile
  ) where

import Control.Exception (IOException, try)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Data.Text.Read qualified as TR

data Command
  = Move Int Int    -- ^ move x y
  | Attack Text     -- ^ attack 目標
  | Rest            -- ^ rest
  deriving stock (Eq, Show)

-- | 錯誤是 ADT:每種失敗都帶著它的上下文,呼叫端可以 pattern match。
-- (對比淘汰做法:回傳 String 錯誤訊息、或在純程式碼丟 exception)
data GameError
  = UnknownCommand Text   -- ^ 整行看不懂
  | BadArguments Text     -- ^ 指令對但參數錯
  | FileError Text        -- ^ 檔案讀不到
  deriving stock (Eq, Show)

-- | (送你)Text 轉 Int。
readInt :: Text -> Maybe Int
readInt t = case TR.signed TR.decimal (T.strip t) of
  Right (n, rest) | T.null rest -> Just n
  _ -> Nothing

-- | 解析玩家指令(先 T.strip 再 T.words):
--
-- * ["move", x, y] 且兩個都是數字 → Move x y;數字爛掉 → BadArguments 原始行
-- * ["attack", 目標]              → Attack 目標
-- * ["rest"]                      → Rest
-- * 其他                          → UnknownCommand 原始行
parseCommand :: Text -> Either GameError Command
parseCommand line = undefined

-- | 給玩家看的錯誤訊息:
--
-- * UnknownCommand c → "未知指令:" <> c
-- * BadArguments c   → "參數錯誤:" <> c
-- * FileError p      → "讀檔失敗:" <> p
renderError :: GameError -> Text
renderError err = undefined

-- | 讀檔,把 IOException 收編成我們的領域錯誤。
-- 提示:try (TIO.readFile path) 的結果是
-- Either IOException Text,把 Left 換成 FileError (T.pack path)。
safeReadFile :: FilePath -> IO (Either GameError Text)
safeReadFile path = undefined
