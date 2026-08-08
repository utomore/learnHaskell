-- | wordcount:第 7 章的完整小程式。
--
-- > cabal run wordcount -- notes/01-first-steps.md
--
-- 注意:用 Data.Text.IO.readFile(嚴格讀檔),
-- 不用 Prelude.readFile(lazy IO,已淘汰)。
module Main (main) where

import Data.Text.IO qualified as TIO
import Examples.WordCount (render, stats)
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [path] -> do
      content <- TIO.readFile path
      TIO.putStr (render (stats content))
    _ -> do
      putStrLn "用法: wordcount <檔案路徑>"
      exitFailure
