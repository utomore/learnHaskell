-- | 第 6 章習題(下):用真套件 streamly-core
--
-- 第 6 章上半手寫 foldLines;這裡把「來源、轉換、消費」拆成
-- streamly 的可組合零件:Stream(來源與轉換)+ Fold(消費)。
-- 把 undefined 換成實作 → cabal test level03-advanced
module Exercises.E09Streamly
  ( linesOf
  , parseCol
  , sumColumnS
  , lineStats
  , firstSquaresOver
  ) where

import Data.Function ((&))
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Data.Text.Read qualified as TR
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream (Stream)
import Streamly.Data.Stream qualified as Stream
import System.IO (Handle, IOMode (ReadMode), hIsEOF, withFile)

-- | 來源:把 Handle 變成「一行一行」的串流。
--
-- 提示:Stream.unfoldrM :: Monad m => (s -> m (Maybe (a, s))) -> s -> Stream m a
-- 狀態 s 就是 Handle;step 檢查 hIsEOF,不是 EOF 就 hGetLine 一行,
-- 回 Just (line, h)。一次只有一行在記憶體裡。
linesOf :: Handle -> Stream IO Text
linesOf = undefined

-- | "slime 10" → Just 10;格式不對 → Nothing。
-- 提示:T.words 之後 pattern match 兩欄,第二欄用 Data.Text.Read.decimal
-- (要求整串都是數字:Right (v, "") 才算成功)。
parseCol :: Text -> Maybe Int
parseCol = undefined

-- | 第二欄加總:來源 → mapMaybe 轉換 → Fold.sum 消費。
-- 提示:withFile path ReadMode $ \h ->
--         linesOf h & Stream.mapMaybe parseCol & Stream.fold Fold.sum
sumColumnS :: FilePath -> IO Int
sumColumnS = undefined

-- | 一趟同時算(行數, 最長行長度)。
-- 提示:先 fmap T.length,再 Stream.fold (Fold.tee Fold.length (Fold.foldl' max 0))。
-- Fold.tee 把兩個 Fold 併成一個,只走一趟。
lineStats :: FilePath -> IO (Int, Int)
lineStats = undefined

-- | 無限串流也能用:從 1 開始平方,取前 n 個大於 limit 的。
-- 提示:Stream.enumerateFrom 1 & fmap (^2) & Stream.filter & Stream.take & Stream.toList
firstSquaresOver :: Int -> Int -> IO [Int]
firstSquaresOver = undefined
