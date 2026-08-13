-- | 第 6 章習題:串流處理
--
-- 把 undefined 換成實作 → cabal test level03-advanced
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
--
-- 骨架:
--   go !acc h = hIsEOF? → pure acc
--               否則 TIO.hGetLine 讀一行,go (step acc line) h
-- 累加器記得加 !(不然就是 IO 版的 foldl space leak)。
foldLines :: (a -> Text -> a) -> a -> Handle -> IO a
foldLines = undefined

-- | 數符合條件的行數。
-- 提示:withFile path ReadMode (foldLines ... ...)——
-- withFile 保證用完(或出例外)一定關檔。
countMatching :: (Text -> Bool) -> FilePath -> IO Int
countMatching = undefined

-- | 最長一行的長度(空檔案回 0)。
longestLine :: FilePath -> IO Int
longestLine = undefined

-- | 每行格式「名字 分數」,加總分數欄;格式爛掉的行跳過。
-- 提示:T.words 拆行,TR.decimal 解析分數(記得檢查沒有剩餘字元)。
sumColumn :: FilePath -> IO Int
sumColumn = undefined
