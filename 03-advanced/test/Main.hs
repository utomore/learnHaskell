-- | Level 3 習題驗收測試。
--
-- > cabal test level03-advanced
-- > cabal test level03-advanced -f solutions
module Main (main) where

import Control.Exception (finally)
import Data.IntSet (IntSet)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Exercises.E01Phantom
import Exercises.E02Gadts
import Exercises.E03TypeFamilies
import Exercises.E04DerivingVia
import Exercises.E05Optics
import Exercises.E06Streaming
import Exercises.E07Performance
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import Hedgehog (forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import System.Directory (getTemporaryDirectory, removeFile)
import System.FilePath ((</>))
import System.IO (hSetEncoding, stderr, stdout)
import Test.Hspec
import Test.Hspec.Hedgehog (hedgehog)

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

-- | 把幾行文字寫進暫存檔,跑完(或出例外)就刪掉。
withTempLines :: [Text] -> (FilePath -> IO a) -> IO a
withTempLines ls act = do
  dir <- getTemporaryDirectory
  let path = dir </> "level03-stream-test.txt"
  TIO.writeFile path (T.unlines ls)
  act path `finally` removeFile path

sampleHero :: Hero
sampleHero = Hero {name = "Rin", stats = Stats {hp = 30, mp = 10}}

spec :: Spec
spec = do
  describe "E01 Phantom types 與 DataKinds" $ do
    it "nextId:數字 +1、標籤保留" $
      nextId (Id 7 :: Id Player) `shouldBe` Id 8
    it "toFahrenheit:100C = 212F" $
      toFahrenheit (Temp 100) `shouldBe` Temp 212
    it "toFahrenheit:0C = 32F" $
      toFahrenheit (Temp 0) `shouldBe` Temp 32
    it "validateName:合法(且有 strip)" $
      validateName (PlayerName " Rin ") `shouldBe` Right (PlayerName "Rin")
    it "validateName:全空白 → 名字不能為空" $
      validateName (PlayerName "   ") `shouldBe` Left "名字不能為空"
    it "validateName:超過 12 字 → 名字太長" $
      validateName (PlayerName "abcdefghijklm") `shouldBe` Left "名字太長"
    it "greet:只收驗證過的名字" $
      greet (PlayerName "Rin") `shouldBe` "歡迎,Rin!"

  describe "E02 GADTs" $ do
    it "eval:算術" $
      eval (Add (IntE 1) (Mul (IntE 2) (IntE 3))) `shouldBe` 7
    it "eval:比較" $
      eval (Leq (IntE 3) (IntE 3)) `shouldBe` True
    it "eval:if 走 else 分支" $
      eval (If (Leq (IntE 5) (IntE 3)) (IntE 1) (IntE 2)) `shouldBe` 2
    it "render:算術加括號" $
      render (Add (IntE 1) (Mul (IntE 2) (IntE 3))) `shouldBe` "(1 + (2 * 3))"
    it "render:if 與布林字面值" $
      render (If (BoolE True) (IntE 1) (IntE 0)) `shouldBe` "if true then 1 else 0"
    it "size:每個建構子算 1" $
      size (If (Leq (IntE 1) (IntE 2)) (IntE 3) (IntE 4)) `shouldBe` 6

  describe "E03 Type families" $ do
    it "fromListC:list(保持順序)" $
      (fromListC [1, 2, 3] :: [Int]) `shouldBe` [1, 2, 3]
    it "fromListC:IntSet(去重排序)" $
      toListC (fromListC [3, 1, 2, 3, 1] :: IntSet) `shouldBe` [1, 2, 3]
    it "fromListC:Text(Elem Text = Char)" $
      (fromListC "abc" :: Text) `shouldBe` "abc"
    it "insertC:Text 是 cons" $
      insertC 'x' ("yz" :: Text) `shouldBe` "xyz"
    it "toListC:Text 轉回 String" $
      toListC ("ab" :: Text) `shouldBe` "ab"
    it "property:list 的 fromListC/toListC 是 roundtrip" $ hedgehog $ do
      xs <- forAll (Gen.list (Range.linear 0 50) (Gen.int (Range.linear (-99) 99)))
      toListC (fromListC xs :: [Int]) === xs

  describe "E04 DerivingVia" $ do
    it "Gold:<> 是相加" $ Gold 3 <> Gold 4 `shouldBe` Gold 7
    it "Gold:mempty 是 0" $ (mempty :: Gold) `shouldBe` Gold 0
    it "totalLoot" $ totalLoot [Gold 1, Gold 2, Gold 3] `shouldBe` Gold 6
    it "HighScore:<> 是取大" $
      HighScore 10 <> HighScore 30 `shouldBe` HighScore 30
    it "bestScore" $
      bestScore [HighScore 5, HighScore 42, HighScore 17] `shouldBe` HighScore 42
    it "Capped:相加封頂 100" $ Capped 60 <> Capped 60 `shouldBe` Capped 100
    it "Rage:借 Capped 的行為(封頂)" $ Rage 70 <> Rage 50 `shouldBe` Rage 100
    it "Rage:沒到頂就正常相加" $ Rage 10 <> Rage 20 `shouldBe` Rage 30
    it "Rage:mempty 是單位元素" $ mempty <> Rage 5 `shouldBe` Rage 5

  describe "E05 Optics" $ do
    it "view:合成 lens 讀巢狀欄位" $
      view heroHpL sampleHero `shouldBe` 30
    it "set:只改聚焦的欄位" $
      set heroHpL 99 sampleHero
        `shouldBe` Hero {name = "Rin", stats = Stats {hp = 99, mp = 10}}
    it "over:單層 lens" $
      over hpL (+ 5) (Stats {hp = 1, mp = 2}) `shouldBe` Stats {hp = 6, mp = 2}
    it "takeDamage:巢狀扣血" $
      takeDamage 12 sampleHero
        `shouldBe` Hero {name = "Rin", stats = Stats {hp = 18, mp = 10}}
    it "takeDamage:不低於 0" $
      takeDamage 999 sampleHero
        `shouldBe` Hero {name = "Rin", stats = Stats {hp = 0, mp = 10}}
    it "property:lens 定律 set-then-view" $ hedgehog $ do
      n <- forAll (Gen.int (Range.linear 0 999))
      view heroHpL (set heroHpL n sampleHero) === n

  describe "E06 串流處理" $ do
    it "countMatching:數 hit 開頭的行" $ do
      n <- withTempLines ["hit 10", "miss", "hit 3"] (countMatching ("hit" `T.isPrefixOf`))
      n `shouldBe` 2
    it "longestLine" $ do
      n <- withTempLines ["a", "abc", "ab"] longestLine
      n `shouldBe` 3
    it "longestLine:空檔案回 0" $ do
      n <- withTempLines [] longestLine
      n `shouldBe` 0
    it "sumColumn:爛行跳過" $ do
      n <- withTempLines ["slime 10", "bat 5", "junk", "dragon 100"] sumColumn
      n `shouldBe` 115
    it "sumColumn:五萬行(逐行 fold 應該瞬間跑完)" $ do
      let m = 50000 :: Int
      n <- withTempLines [T.pack ("mob " <> show i) | i <- [1 .. m]] sumColumn
      n `shouldBe` m * (m + 1) `div` 2

  describe "E07 效能調校" $ do
    it "sumAndLength:一趟,一百萬個元素" $
      sumAndLength [1 .. 1000000] `shouldBe` (500000500000, 1000000)
    it "meanInt:正常" $ meanInt [1 .. 10] `shouldBe` 5.5
    it "meanInt:空 list 回 0" $ meanInt [] `shouldBe` 0
    it "histogram" $
      histogram ["axe", "bow", "axe"]
        `shouldBe` Map.fromList [("axe", 2), ("bow", 1)]
    it "property:histogram 的計數總和 = 輸入長度" $ hedgehog $ do
      ws <- forAll (Gen.list (Range.linear 0 100) (Gen.element ["a", "b", "c", "d"]))
      sum (Map.elems (histogram ws)) === length ws
    it "sumSquaresEven:小輸入" $ sumSquaresEven 10 `shouldBe` 220
    it "sumSquaresEven:兩百萬(fusion 後應該瞬間跑完)" $ do
      let m = 1000000 :: Int
      sumSquaresEven 2000000 `shouldBe` 4 * (m * (m + 1) * (2 * m + 1) `div` 6)
