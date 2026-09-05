# 第 7 章 — 測試:hspec 單元測試 + hedgehog 性質測試

## 你已經在用 hspec

兩級的驗收測試都是 hspec:`describe` 分組、`it` 一條測試、
`shouldBe`/`shouldReturn`/`shouldSatisfy` 斷言。結構複習:

```haskell
main = hspec $ do
  describe "模組或功能" $ do
    it "描述行為" $ actual `shouldBe` expected
```

### hspec 與 tasty:兩個生態的定位

| | hspec | tasty |
|---|---|---|
| 風格 | RSpec 式的 `describe`/`it`,一個框架包到底 | 只做測試樹與執行器,斷言/性質靠外掛(`tasty-hunit`、`tasty-hedgehog`、`tasty-bench`) |
| 適合 | 應用程式、教學、想少裝套件 | 函式庫、要把 benchmark 和測試放同一棵樹 |
| 2026 現況 | 兩者並行,都活躍;選一個就好 | |

它們不是新舊關係,是口味。本課程用 hspec 因為它不需要組合,
但你讀開源專案會兩種都遇到,結構都一樣是「樹 + 葉子」。

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
最小反例再回報。

### 親眼看一次失敗

把 `insertSorted` 故意寫錯——直接接在最前面:

```haskell
insertSorted :: Int -> [Int] -> [Int]
insertSorted x xs = x : xs
```

跑測試,hedgehog 的真實輸出:

```
insertSorted 保持有序 [✘]

Failures:

  app\HH.hs:28:7:
  1) insertSorted 保持有序
       failed after 3 tests and 1 shrink.
       shrink path: 3:e

          ┏━━ app\HH.hs ━━━
       25 ┃       x <- forAll (Gen.int (Range.linear (-100) 100))
          ┃       │ -97
       26 ┃       xs <- forAll (Gen.list (Range.linear 0 50) (Gen.int (Range.linear (-100) 100)))
          ┃       │ [ -100 ]
       27 ┃       let result = insertSorted x (sort xs)
       28 ┃       assert (isSorted result)
          ┃       ^^^^^^^^^^^^^^^^^^^^^^^^
       29 ┃       length result === length xs + 1

  To rerun use: --match "/insertSorted 保持有序/" --seed 1603357006
```

逐段讀:

- `failed after 3 tests and 1 shrink`:第 3 組隨機輸入就抓到,然後縮小了 1 步。
- 每個 `forAll` 下面的 `│ -97`、`│ [ -100 ]` 是**縮小後**的輸入:
  `x = -97` 插進 `[-100]` 得到 `[-97, -100]`,沒排序。
  你看到的不是一個 47 元素的怪 list,而是一眼看穿的兩個數字。
- `^^^^` 指出哪個斷言掛了。
- `--seed 1603357006`:失敗是可重現的,把 seed 帶回去就能重跑同一組輸入。

hedgehog 會**讀你的原始檔**來畫這張圖——這是 Level 2 測試檔要
`setLocaleEncoding utf8` 的另一個原因:Windows 預設 CP950 讀 UTF-8 的
中文測試名稱會直接炸成 `hGetContents: invalid argument`。

## 舊做法 → 新做法:QuickCheck 與 hedgehog

**QuickCheck**(Claessen & Hughes,2000)發明了性質測試,是所有語言
同類工具的祖先。它的設計:每個型別寫一個 `Arbitrary` instance,
`arbitrary` 生資料、`shrink` 縮小。問題在實務上慢慢浮現:

1. **typeclass 綁死型別**:一個型別只能有一個 `Arbitrary`。想要「1..100 的 Int」
   和「任意 Int」兩種分布,就得包 newtype,程式碼裡到處是 `Positive`、`NonEmpty` 包裝。
2. **`shrink` 要手寫**,而且和 `arbitrary` 分開寫。忘了寫(預設是空 list)
   就得到一個 47 元素的爛反例;寫了但和 generator 不一致,shrink 會產生
   generator 根本生不出來的輸入,讓你追一個不存在的 bug。

**hedgehog**(Jacob Stanley,2017)的兩個修正:

- generator 是**一等值**:`Gen.int (Range.linear 0 100)` 就是一個值,
  用組合子拼,同一個型別要幾種分布就寫幾個,不靠 typeclass。
- **shrinking 內建於 generator**:每個 `Gen` 同時描述「怎麼生」和「怎麼縮」,
  組合 generator 時 shrink 自動跟著組合,永遠一致。上面那個
  `[ -100 ]` 反例就是免費得到的。

同世代的 **falsify**(Edsko de Vries,2023,tasty 生態)想法相同、
shrink 理論更新(不靠 rose tree,直接縮小隨機源),用 tasty 的專案可以選它。
QuickCheck 仍然到處都是(很多函式庫的測試),讀得懂 `Arbitrary`、
`property`、`==>` 即可;新專案寫 hedgehog。

## 什麼是好性質

- **不變量**:排序後有序;長度守恆;錢的總額不變
- **roundtrip**:`parse (render x) == Just x`(最有價值的一類!序列化必寫)
- **對照模型**:優化版 == 樸素版(`myReplicate n x == replicate n x`)
- **冪等**:`normalize (normalize x) == normalize x`
- **交換/結合**:`a <> b == b <> a`(如果該成立的話)——Level 1 的 Monoid law
  測試就是這種

反面:把實作照抄一遍當性質(恆真,測不到東西)。
判斷方法:這條性質**能不能被一個錯的實作違反**?不能就刪掉。

## Generator 語彙

```haskell
Gen.int (Range.linear 0 100)      -- 整數,線性成長範圍
Gen.list (Range.linear 0 50) g    -- 用 g 生出 list
Gen.text (Range.linear 1 10) Gen.alpha
Gen.element [Fire, Ice, Lightning]  -- 從清單挑一個
Gen.choice [g1, g2]               -- 從幾個 generator 挑一個
Gen.filter p g                    -- 過濾(小心別濾掉 99%)
```

`Range.linear 0 50` 的意思是「size 從小到大線性長到 50」——
hedgehog 前幾組測試會用小輸入,越跑越大,所以 bug 通常在小輸入就被抓到。

### `Gen.filter` 為什麼危險

`Gen.filter even (Gen.int ...)` 會**生了再丟**:不符合就重生,重試 100 次
還沒有就放棄整條測試(報 `Gen.filter` 失敗,不是你的性質失敗)。
過濾掉一半沒問題;過濾掉 99%(例如「必須是質數」)就會拖慢或直接失敗。
正確做法是**建構**而非**過濾**:`(* 2) <$> Gen.int ...` 直接生偶數。

## 你會看到的錯誤訊息

不是編譯錯誤,而是**測試本身有問題**時 hedgehog 的回報,最常見兩種:

1. `Gen.filter` 濾太兇(例如 `Gen.filter (> 99999) (Gen.int (Range.linear 0 100))`):

   ```
   1) filter too aggressive
        gave up after 1000 discards, passed 0 tests.
   ```

   意思是「我生不出符合條件的輸入」,性質根本沒被測到——`passed 0 tests` 是重點。
2. 性質恆真:什麼都不會報,`100 tests passed`——這是最危險的一種,
   請用「故意把實作改壞」來確認測試真的會紅。本章上面那個示範就是這個習慣。

## ghci 實驗

hedgehog 的 generator 可以直接在 ghci 抽樣看分布:

```haskell
ghci> import Hedgehog.Gen qualified as Gen
ghci> import Hedgehog.Range qualified as Range
ghci> Gen.sample (Gen.int (Range.linear 0 100))
18
ghci> Gen.sample (Gen.list (Range.linear 0 5) Gen.alpha)
""
ghci> Gen.sample (Gen.choice [Gen.int (Range.linear 0 9), Gen.int (Range.linear 100 109)])
103
ghci> Gen.print (Gen.int (Range.linear 0 10))   -- 印一個值和它的 shrink 候選
=== Outcome ===
0
=== Shrinks ===
```

(輸出是隨機的,你的數字會不一樣;抽到 0 時 shrink 清單是空的,
抽到較大的數就會列出往 0 靠近的候選——多跑幾次看看。)`Gen.print` 直接把
「這個值會怎麼縮小」畫出來,是理解 hedgehog 的最快方式。

## 常見誤區

- **性質寫成實作的複製品。** 測不到東西;改用不變量或對照模型。
- **只寫性質不寫例子。** 邊界案例(空 list、0、最大值)用 `it ... shouldBe` 直接釘死最清楚。
- **`Gen.filter` 當主要工具。** 改成建構式 generator。
- **失敗了不看 shrink 後的輸入。** 那才是 hedgehog 最值錢的部分。
- **不確認測試會紅。** 新性質寫完先把實作弄壞跑一次。

## 習題

`exercises/Exercises/E07Testing.hs` 實作 `insertSorted` 與 `myReplicate`,
然後**打開 `test/Main.hs` 讀 E07 區塊的性質怎麼寫** ——
這章的重點有一半在測試檔裡。E05 的 `takeUntilBudget` 也有一條
「總花費 ≤ 預算」的性質在等你。
