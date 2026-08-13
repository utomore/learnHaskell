-- | 第 6 章習題:串流處理(參考解答)
module Exercises.E06Streaming
  ( foldLines
  , countMatching
  , longestLine
  , sumColumn
  ) where

import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Data.Text.Read qualified as TR
import System.IO (Handle, IOMode (ReadMode), hIsEOF, withFile)

-- | foldl' 的 IO 版:逐行讀、嚴格累加,記憶體 O(1),檔案多大都一樣。
foldLines :: (a -> Text -> a) -> a -> Handle -> IO a
foldLines step = go
  where
    go !acc h = do
      eof <- hIsEOF h
      if eof
        then pure acc
        else do
          line <- TIO.hGetLine h
          go (step acc line) h

-- | 數符合條件的行數。withFile 保證用完(或出例外)一定關檔。
countMatching :: (Text -> Bool) -> FilePath -> IO Int
countMatching p path =
  withFile path ReadMode (foldLines (\n l -> if p l then n + 1 else n) 0)

-- | 最長一行的長度(空檔案回 0)。
longestLine :: FilePath -> IO Int
longestLine path =
  withFile path ReadMode (foldLines (\m l -> max m (T.length l)) 0)

-- | 每行格式「名字 分數」,加總分數欄;格式爛掉的行跳過。
sumColumn :: FilePath -> IO Int
sumColumn path = withFile path ReadMode (foldLines step 0)
  where
    step acc line = case T.words line of
      [_, score]
        | Right (n, rest) <- TR.decimal score
        , T.null rest ->
            acc + n
      _ -> acc
