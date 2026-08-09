-- | 第 6 章參考解答
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
  = Move Int Int
  | Attack Text
  | Rest
  deriving stock (Eq, Show)

data GameError
  = UnknownCommand Text
  | BadArguments Text
  | FileError Text
  deriving stock (Eq, Show)

readInt :: Text -> Maybe Int
readInt t = case TR.signed TR.decimal (T.strip t) of
  Right (n, rest) | T.null rest -> Just n
  _ -> Nothing

parseCommand :: Text -> Either GameError Command
parseCommand line = case T.words (T.strip line) of
  ["move", xs, ys] -> case (readInt xs, readInt ys) of
    (Just x, Just y) -> Right (Move x y)
    _ -> Left (BadArguments line)
  ["attack", target] -> Right (Attack target)
  ["rest"] -> Right Rest
  _ -> Left (UnknownCommand line)

renderError :: GameError -> Text
renderError = \case
  UnknownCommand c -> "未知指令:" <> c
  BadArguments c -> "參數錯誤:" <> c
  FileError p -> "讀檔失敗:" <> p

safeReadFile :: FilePath -> IO (Either GameError Text)
safeReadFile path = do
  result <- try (TIO.readFile path)
  pure $ case result of
    Left (_ :: IOException) -> Left (FileError (T.pack path))
    Right content -> Right content
