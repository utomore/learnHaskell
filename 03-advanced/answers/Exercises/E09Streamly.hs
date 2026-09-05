-- | 第 6 章習題(下):用真套件 streamly-core(參考解答)
--
-- 第 6 章上半手寫 foldLines;這裡把「來源、轉換、消費」拆成
-- streamly 的可組合零件:Stream(來源與轉換)+ Fold(消費)。
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
-- unfoldrM 每次呼叫 step 產生一個元素(或 Nothing 結束);
-- 一次只有一行在記憶體裡 —— 這和第 6 章上半的 go 迴圈是同一件事,
-- 只是「產生下一行」和「拿這行做什麼」被拆開了。
linesOf :: Handle -> Stream IO Text
linesOf = Stream.unfoldrM step
  where
    step h = do
      eof <- hIsEOF h
      if eof
        then pure Nothing
        else do
          line <- TIO.hGetLine h
          pure (Just (line, h))

-- | "slime 10" → Just 10;格式不對 → Nothing。
parseCol :: Text -> Maybe Int
parseCol line = case T.words line of
  [_, n] | Right (v, "") <- TR.decimal n -> Just v
  _ -> Nothing

-- | 第二欄加總:來源 → mapMaybe 轉換 → Fold.sum 消費。
sumColumnS :: FilePath -> IO Int
sumColumnS path = withFile path ReadMode $ \h ->
  linesOf h
    & Stream.mapMaybe parseCol
    & Stream.fold Fold.sum

-- | 一趟同時算(行數, 最長行長度):Fold.tee 把兩個 Fold 併成一個。
lineStats :: FilePath -> IO (Int, Int)
lineStats path = withFile path ReadMode $ \h ->
  linesOf h
    & fmap T.length
    & Stream.fold (Fold.tee Fold.length (Fold.foldl' max 0))

-- | 無限串流也能用:從 1 開始平方,取前 n 個大於 limit 的。
firstSquaresOver :: Int -> Int -> IO [Int]
firstSquaresOver limit n =
  Stream.enumerateFrom (1 :: Int)
    & fmap (\x -> x * x)
    & Stream.filter (> limit)
    & Stream.take n
    & Stream.toList
