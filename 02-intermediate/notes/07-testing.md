# 第 7 章 — 測試:hspec 單元測試 + hedgehog 性質測試

## 你已經在用 hspec

兩級的驗收測試都是 hspec:`describe` 分組、`it` 一條測試、
`shouldBe`/`shouldReturn`/`shouldSatisfy` 斷言。結構複習:

```haskell
main = hspec $ do
  describe "模組或功能" $ do
    it "描述行為" $ actual `shouldBe` expected
```

## Property-based testing:測性質,不測例子

單元測試驗證「這個輸入給這個輸出」;性質測試驗證
「**對所有(隨機)輸入,這個不變量恆成立**」:

```haskell
import Hedgehog (assert, forAll, (===))
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Test.Hspec.Hedgehog (hedgehog)

it "insertSorted 保持有序" $ hedgehog $ do
  x  <- forAll (Gen.int (Range.linear (-100) 100))
  xs <- forAll (Gen.list (Range.linear 0 50) (Gen.int (Range.linear (-100) 100)))
  let result = insertSorted x (sort xs)
  assert (isSorted result)
  length result === length xs + 1
```

跑 100 組隨機輸入;一失敗,hedgehog 自動**縮小**(shrink)到
最小反例再回報 —— 你看到的不是一個 47 元素的怪 list,
而是 `[0,0]` 這種一眼看穿的輸入。

**為什麼選 hedgehog(2026 觀點)**:generator 是一等值
(組合子拼出來,不靠 typeclass 魔法)、shrinking 內建於 generator
(QuickCheck 要手寫 `shrink`,忘了寫就得到爛反例)。
同世代的 **falsify**(tasty 生態)想法相同、shrink 理論更新,
用 tasty 的專案可以選它。QuickCheck 是經典,讀得懂即可。

## 什麼是好性質

- **不變量**:排序後有序;長度守恆;錢的總額不變
- **roundtrip**:`parse (render x) == Just x`(最有價值的一類!序列化必寫)
- **對照模型**:優化版 == 樸素版(`myReplicate n x == replicate n x`)
- **冪等**:`normalize (normalize x) == normalize x`

反面:把實作照抄一遍當性質(恆真,測不到東西)。

## Generator 語彙

```haskell
Gen.int (Range.linear 0 100)      -- 整數,線性成長範圍
Gen.list (Range.linear 0 50) g    -- 用 g 生出 list
Gen.text (Range.linear 1 10) Gen.alpha
Gen.element [Fire, Ice, Lightning]  -- 從清單挑一個
Gen.filter p g                    -- 過濾(小心別濾掉 99%)
```

## 習題

`exercises/Exercises/E07Testing.hs` 實作 `insertSorted` 與 `myReplicate`,
然後**打開 `test/Main.hs` 讀 E07 區塊的性質怎麼寫** ——
這章的重點有一半在測試檔裡。E05 的 `takeUntilBudget` 也有一條
「總花費 ≤ 預算」的性質在等你。
