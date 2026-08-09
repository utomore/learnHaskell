-- | 第 8 章參考解答
module Exercises.E08Concurrency
  ( transferGold
  , inParallel
  , raceFirst
  ) where

import Control.Concurrent.Async (concurrently, race)
import Control.Concurrent.STM (STM, TVar, modifyTVar')

transferGold :: TVar Int -> TVar Int -> Int -> STM ()
transferGold from to n = do
  modifyTVar' from (subtract n)
  modifyTVar' to (+ n)

inParallel :: IO a -> IO b -> IO (a, b)
inParallel = concurrently

raceFirst :: IO a -> IO a -> IO a
raceFirst ioA ioB = either id id <$> race ioA ioB
