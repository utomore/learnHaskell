-- | Level 2 習題驗收測試。
--
-- > cabal test level02-intermediate
-- > cabal test level02-intermediate -f solutions
module Main (main) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (mapConcurrently_)
import Control.Concurrent.STM (atomically, newTVarIO, readTVarIO)
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import Exercises.E01Functors
import Exercises.E02Applicative
import Exercises.E03Monads
import Exercises.E04Traverse
import Exercises.E05Laziness
import Exercises.E06Errors
import Exercises.E07Testing
import Exercises.E08Concurrency
import Hedgehog (assert, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import System.IO (hSetEncoding, stderr, stdout)
import Test.Hspec
import Test.Hspec.Hedgehog (hedgehog)

isSorted :: [Int] -> Bool
isSorted xs = and (zipWith (<=) xs (drop 1 xs))

main :: IO ()
main = do
  -- Windows 的預設編碼是 console codepage(CP950),會造成兩個問題:
  -- 1. 中文測試名稱輸出成亂碼
  -- 2. TIO.readFile 用 CP950 解碼 UTF-8 檔案 → 丟 IOException
  -- 統一改成 UTF-8(setLocaleEncoding 管之後開的 handle,含 readFile)。
  setLocaleEncoding utf8
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  hspec spec

spec :: Spec
spec = do
  describe "E01 Functor" $ do
    it "Chest:fmap 套用到內容" $ fmap (+ 1) (Chest (1 :: Int)) `shouldBe` Chest 2
    it "Chest:空箱維持空箱" $ fmap (+ 1) (EmptyChest :: Chest Int) `shouldBe` EmptyChest
    it "Chest law:fmap id = id" $ fmap id (Chest 'x') `shouldBe` Chest 'x'
    it "Pair:兩邊都套用" $ fmap (* 2) (Pair 1 (2 :: Int)) `shouldBe` Pair 2 4
    it "buffAll:list" $ buffAll 5 [1, 2] `shouldBe` [6, 7]
    it "buffAll:Maybe" $ buffAll 5 (Just 10) `shouldBe` Just 15
    it "buffAll:Chest" $ buffAll 5 (Chest 1) `shouldBe` Chest 6

  describe "E02 Applicative" $ do
    it "Buff:pure" $ (pure 'x' :: Buff Char) `shouldBe` Buff 'x'
    it "Buff:兩邊都有" $ (Buff (+ 1) <*> Buff (1 :: Int)) `shouldBe` Buff 2
    it "Buff:一邊沒有" $ (NoBuff <*> Buff (1 :: Int)) `shouldBe` (NoBuff :: Buff Int)
    it "liftPair:Maybe" $ liftPair (Just (1 :: Int)) (Just 'x') `shouldBe` Just (1, 'x')
    it "liftPair:Nothing 傳染" $
      liftPair (Just (1 :: Int)) (Nothing :: Maybe Char) `shouldBe` Nothing
    it "mkHero:合法" $
      mkHero " Rin " 80 `shouldBe` Right Hero {name = "Rin", hp = 80}
    it "mkHero:名字全空白" $ mkHero "   " 80 `shouldBe` Left "名字不能為空"
    it "mkHero:HP 超界" $ mkHero "Rin" 0 `shouldBe` Left "HP 必須在 1..100"
    it "mkHero:fail-fast(回報第一個錯)" $
      mkHero "" 999 `shouldBe` Left "名字不能為空"

  describe "E03 Monad" $ do
    it "andThen:成功串接" $ andThen (Just 3) (\x -> Just (x + 1)) `shouldBe` Just (4 :: Int)
    it "andThen:Nothing 短路" $
      andThen Nothing (\x -> Just (x + 1 :: Int)) `shouldBe` Nothing
    it "andThen:下一步失敗" $
      andThen (Just (3 :: Int)) (const (Nothing :: Maybe Int)) `shouldBe` Nothing
    let equips = Map.fromList [("Rin", "iceblade")]
        stats = Map.fromList [("iceblade", 42 :: Int)]
    it "weaponDamage:兩層都查到" $ weaponDamage equips stats "Rin" `shouldBe` Just 42
    it "weaponDamage:英雄不存在" $ weaponDamage equips stats "Bob" `shouldBe` Nothing
    it "weaponDamage:武器沒屬性" $
      weaponDamage (Map.fromList [("Rin", "stick")]) stats "Rin" `shouldBe` Nothing
    it "allPairs:順序正確" $
      allPairs [1 :: Int, 2] "ab"
        `shouldBe` [(1, 'a'), (1, 'b'), (2, 'a'), (2, 'b')]
    it "avgDamage:正常" $ avgDamage [10, 20] `shouldBe` Just 15.0
    it "avgDamage:空清單" $ avgDamage [] `shouldBe` Nothing

  describe "E04 Foldable/Traversable" $ do
    it "openAll:全部成功" $ openAll [Just (1 :: Int), Just 2] `shouldBe` Just [1, 2]
    it "openAll:一箱失敗" $ openAll [Just (1 :: Int), Nothing] `shouldBe` Nothing
    it "openAll:空清單成功" $ openAll ([] :: [Maybe Int]) `shouldBe` Just []
    it "parseAllInts:全數字" $ parseAllInts ["1", "-2", " 3 "] `shouldBe` Just [1, -2, 3]
    it "parseAllInts:混入垃圾" $ parseAllInts ["1", "x"] `shouldBe` Nothing
    let party =
          [ Adventurer "Rin" 80 120
          , Adventurer "Kai" 0 30
          ]
    it "partyGold" $ partyGold party `shouldBe` 150
    it "allAlive:有人倒下" $ allAlive party `shouldBe` False
    it "allAlive:空隊伍算 True" $ allAlive [] `shouldBe` True

  describe "E05 惰性求值" $ do
    it "average:空清單" $ average [] `shouldBe` Nothing
    it "average:一百萬個元素(嚴格累加不爆記憶體)" $
      average [1 .. 1_000_000] `shouldBe` Just 500000.5
    it "firstNegative:在『無限』list 裡找(惰性)" $
      firstNegative ([5, 4] ++ [-9] ++ [1 ..]) `shouldBe` Just (-9)
    it "takeUntilBudget:剛好花完" $ takeUntilBudget 5 [2, 2, 2, 2] `shouldBe` [2, 2]
    it "takeUntilBudget:無限 list(惰性產出)" $
      takeUntilBudget 10 (repeat 3) `shouldBe` [3, 3, 3]
    it "takeUntilBudget property:總花費不超過預算" $ hedgehog $ do
      budget <- forAll (Gen.int (Range.linear 0 100))
      costs <- forAll (Gen.list (Range.linear 0 30) (Gen.int (Range.linear 0 20)))
      assert (sum (takeUntilBudget budget costs) <= budget)

  describe "E06 錯誤處理" $ do
    it "parseCommand:move" $ parseCommand "move 2 -3" `shouldBe` Right (Move 2 (-3))
    it "parseCommand:attack" $ parseCommand "attack slime" `shouldBe` Right (Attack "slime")
    it "parseCommand:rest(含空白)" $ parseCommand "  rest  " `shouldBe` Right Rest
    it "parseCommand:move 參數爛掉" $
      parseCommand "move a b" `shouldBe` Left (BadArguments "move a b")
    it "parseCommand:看不懂" $
      parseCommand "dance" `shouldBe` Left (UnknownCommand "dance")
    it "renderError:UnknownCommand" $
      renderError (UnknownCommand "dance") `shouldBe` "未知指令:dance"
    it "renderError:FileError" $
      renderError (FileError "a.txt") `shouldBe` "讀檔失敗:a.txt"
    it "safeReadFile:讀得到" $ do
      result <- safeReadFile "level02-intermediate.cabal"
      (T.isInfixOf "level02" <$> result) `shouldBe` Right True
    it "safeReadFile:檔案不存在 → FileError" $ do
      result <- safeReadFile "no-such-file-xyz.txt"
      result `shouldBe` Left (FileError "no-such-file-xyz.txt")

  describe "E07 Property-based testing(hedgehog)" $ do
    it "insertSorted:單元測試" $ insertSorted 3 [1, 2, 4] `shouldBe` [1, 2, 3, 4]
    it "insertSorted property:輸出保持有序且長度 +1" $ hedgehog $ do
      x <- forAll (Gen.int (Range.linear (-100) 100))
      xs <- forAll (Gen.list (Range.linear 0 50) (Gen.int (Range.linear (-100) 100)))
      let result = insertSorted x (sort xs)
      assert (isSorted result)
      length result === length xs + 1
      assert (x `elem` result)
    it "myReplicate property:長度與內容" $ hedgehog $ do
      n <- forAll (Gen.int (Range.linear (-5) 50))
      let result = myReplicate n 'k'
      length result === max 0 n
      assert (all (== 'k') result)

  describe "E08 並行" $ do
    it "transferGold:100 條執行緒同時轉帳,總額不變" $ do
      a <- newTVarIO (1000 :: Int)
      b <- newTVarIO 0
      mapConcurrently_ id (replicate 100 (atomically (transferGold a b 5)))
      finalA <- readTVarIO a
      finalB <- readTVarIO b
      (finalA, finalB) `shouldBe` (500, 500)
    it "inParallel:拿到兩個結果" $
      inParallel (pure (1 :: Int)) (pure True) `shouldReturn` (1, True)
    it "raceFirst:快的贏" $ do
      result <- raceFirst (threadDelay 500_000 >> pure "slow") (pure ("fast" :: String))
      result `shouldBe` "fast"
