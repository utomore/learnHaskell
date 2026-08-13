-- | Level 1 習題驗收測試。
--
-- > cabal test level01-foundations                -- 測你的習題
-- > cabal test level01-foundations -f solutions   -- 測參考解答(應全綠)
module Main (main) where

import Data.Map.Strict qualified as Map
import Exercises.E01Basics
import Exercises.E02Functions
import Exercises.E03Lists
import Exercises.E04Adts
import Exercises.E05Classes
import Exercises.E06Text
import Exercises.E07IO
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import System.IO (hSetEncoding, stderr, stdout)
import Test.Hspec

main :: IO ()
main = do
  -- Windows 預設用 console codepage(CP950)輸出,中文會變亂碼,統一改 UTF-8
  setLocaleEncoding utf8
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  hspec spec

spec :: Spec
spec = do
  describe "E01 基本運算式" $ do
    it "hitPoints:正常扣血" $ hitPoints 100 30 `shouldBe` 70
    it "hitPoints:不低於 0" $ hitPoints 20 50 `shouldBe` 0
    it "distance:3-4-5 三角形" $ distance 0 0 3 4 `shouldBe` 5.0
    it "distance:同一點" $ distance 2 2 2 2 `shouldBe` 0.0
    it "xpForNextLevel" $ xpForNextLevel 3 `shouldBe` 350
    it "isCritical:95 是暴擊" $ isCritical 95 `shouldBe` True
    it "isCritical:94 不是" $ isCritical 94 `shouldBe` False
    it "secondsToHms" $ secondsToHms 3725 `shouldBe` (1, 2, 5)
    it "secondsToHms:0 秒" $ secondsToHms 0 `shouldBe` (0, 0, 0)

  describe "E02 函式與 pattern matching" $ do
    it "describeHp:倒下" $ describeHp 0 `shouldBe` "倒下"
    it "describeHp:瀕死" $ describeHp 10 `shouldBe` "瀕死"
    it "describeHp:受傷" $ describeHp 50 `shouldBe` "受傷"
    it "describeHp:健康" $ describeHp 90 `shouldBe` "健康"
    it "clamp':超過上限" $ clamp' 0 100 120 `shouldBe` 100
    it "clamp':低於下限" $ clamp' 0 100 (-5) `shouldBe` 0
    it "clamp':區間內" $ clamp' 0 100 42 `shouldBe` 42
    it "safeDivide:正常" $ safeDivide 10 4 `shouldBe` Just 2.5
    it "safeDivide:除以零" $ safeDivide 1 0 `shouldBe` Nothing
    it "applyTwice" $ applyTwice (+ 3) (10 :: Int) `shouldBe` 16
    it "fizzbuzz:15 的倍數" $ fizzbuzz 30 `shouldBe` "FizzBuzz"
    it "fizzbuzz:3 的倍數" $ fizzbuzz 9 `shouldBe` "Fizz"
    it "fizzbuzz:5 的倍數" $ fizzbuzz 10 `shouldBe` "Buzz"
    it "fizzbuzz:其他" $ fizzbuzz 7 `shouldBe` "7"

  describe "E03 List 與遞迴" $ do
    it "myLength" $ myLength [1 :: Int, 2, 3] `shouldBe` 3
    it "myLength:空 list" $ myLength ([] :: [Int]) `shouldBe` 0
    it "myReverse" $ myReverse [1 :: Int, 2, 3] `shouldBe` [3, 2, 1]
    it "safeHead:非空" $ safeHead [7 :: Int] `shouldBe` Just 7
    it "safeHead:空" $ safeHead ([] :: [Int]) `shouldBe` Nothing
    it "totalDamage" $ totalDamage [10, 20, 5] `shouldBe` 35
    it "totalDamage:大量資料不爆記憶體" $
      totalDamage [1 .. 1_000_000] `shouldBe` 500000500000
    it "aliveCount" $ aliveCount [10, 0, -3, 5] `shouldBe` 2
    it "zipWithIndex" $
      zipWithIndex "abc" `shouldBe` [(0, 'a'), (1, 'b'), (2, 'c')]

  describe "E04 ADT 與 record" $ do
    it "effectiveness:克制 2 倍" $ effectiveness Fire Ice `shouldBe` 2.0
    it "effectiveness:同屬性 0.5" $ effectiveness Ice Ice `shouldBe` 0.5
    it "effectiveness:其他 1.0" $ effectiveness Ice Fire `shouldBe` 1.0
    it "area:圓" $ area (Circle 1) `shouldBe` pi
    it "area:矩形" $ area (Rect 3 4) `shouldBe` 12
    let hero = Player {name = "Hero", hp = 80, maxHp = 100}
    it "heal:正常補血" $ (heal 15 hero).hp `shouldBe` 95
    it "heal:不超過上限" $ (heal 50 hero).hp `shouldBe` 100
    it "describePlayer" $ describePlayer hero `shouldBe` "Hero (HP 80/100)"
    it "eval:巢狀算式" $
      eval (Add (Lit 1) (Mul (Lit 2) (Lit 3))) `shouldBe` 7
    it "eval:負號" $ eval (Neg (Add (Lit 2) (Lit 3))) `shouldBe` (-5)

  describe "E05 Typeclass 與 Monoid" $ do
    it "Semigroup:金幣相加" $ Gold 3 <> Gold 4 `shouldBe` Gold 7
    it "Monoid:mempty 是 0" $ (mempty :: Gold) `shouldBe` Gold 0
    it "Monoid law:左單位元" $ mempty <> Gold 9 `shouldBe` Gold 9
    let items =
          [ Item "藥水" (Gold 50)
          , Item "長劍" (Gold 300)
          , Item "麵包" (Gold 10)
          ]
    it "totalPrice" $ totalPrice items `shouldBe` Gold 360
    it "totalPrice:空清單" $ totalPrice [] `shouldBe` Gold 0
    it "cheapest" $ (.name) <$> cheapest items `shouldBe` Just "麵包"
    it "cheapest:空清單" $ cheapest [] `shouldBe` Nothing

  describe "E06 Text" $ do
    it "shout" $ shout "hello" `shouldBe` "HELLO!"
    it "countWords" $ countWords "the quick brown fox" `shouldBe` 4
    it "slugify" $ slugify "Hello World! 123" `shouldBe` "hello-world-123"
    it "attackMessage" $
      attackMessage "Hero" "Slime" 12 `shouldBe` "Hero 對 Slime 造成 12 點傷害"
    it "wordFreq" $
      wordFreq "a b a c a b"
        `shouldBe` Map.fromList [("a", 3), ("b", 2), ("c", 1)]

  describe "E07 IO 的純核心" $ do
    it "numberLines" $ numberLines "aa\nbb" `shouldBe` "1: aa\n2: bb\n"
    it "parseKeyValue:正常" $
      parseKeyValue "name = Hero" `shouldBe` Just ("name", "Hero")
    it "parseKeyValue:沒有等號" $ parseKeyValue "無效的行" `shouldBe` Nothing
    it "parseConfig" $
      parseConfig "name=Hero\n這行壞掉了\nhp = 100"
        `shouldBe` Map.fromList [("name", "Hero"), ("hp", "100")]
