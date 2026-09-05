# 第 5 章 — Typeclass、Deriving Strategies、Semigroup/Monoid

## Typeclass:有原則的多載

typeclass 是「一組型別必須提供的操作」——類似其他語言的 interface/trait,
但由**型別**實作而不是物件:

```haskell
class Eq a where
  (==) :: a -> a -> Bool

instance Eq Element where
  Fire == Fire = True
  Ice == Ice = True
  Lightning == Lightning = True
  _ == _ = False
```

型別簽名裡的 `Eq a =>` 是**約束**:

```haskell
elem' :: Eq a => a -> [a] -> Bool   -- 「任何有 Eq 的 a 都行」
```

常用內建 class:`Eq`(相等)、`Ord`(排序)、`Show`(轉字串除錯用)、
`Enum`/`Bounded`(列舉)、`Num`/`Fractional`(數字)。

回頭看第 1 章的 `3 :: Num a => a`:現在你知道 `Num` 是一個 class,
`+`、`*`、`fromInteger` 是它的方法,數字字面值就是 `fromInteger 3` 的簡寫 ——
所以任何實作了 `Num` 的型別都能直接寫 `3`。這就是「有原則的多載」:
不是編譯器對數字特別開後門,而是一套所有人都能用的機制。

### Typeclass 為什麼不是 OOP interface

Haskell 1.0 引入 typeclass 是為了解決一個具體問題:`==` 和 `+` 要能對多種型別使用,
但又不想像 Lisp 那樣在執行期檢查型別。答案是「在編譯期依型別挑實作」,
這和 OOP 的「在執行期依物件挑方法」是兩條路。三個實際差別:

- instance 可以事後補:別人的型別 + 你的 class 也能寫 instance。
- dispatch 依**型別**而非執行期物件 —— `mempty :: Gold` 沒有任何「物件」存在,
  純粹是型別告訴編譯器「用 Gold 的那個 mempty」。OOP 做不到「回傳型別決定行為」。
- 一個型別對一個 class 只能有一個 instance(全域一致性)。這是刻意的限制:
  `Map` 的排序依賴 `Ord`,如果同一個型別可以有兩個 `Ord` instance,
  一個 Map 在兩個模組間傳遞就會壞掉。

## Deriving:讓編譯器幫你寫 instance

**2026 慣例:一律標明 deriving strategy**,不寫裸的 `deriving (...)`:

```haskell
data Element = Fire | Ice | Lightning
  deriving stock (Eq, Ord, Show, Enum, Bounded)
  -- stock = GHC 內建的標準推導

newtype Gold = Gold Int
  deriving newtype (Eq, Ord, Show)
  -- newtype = 直接沿用底層型別(Int)的 instance,零成本
```

為什麼要標?`deriving (Show)` 對 newtype 是要 `Gold 3` 還是 `3`?
兩種都合理,所以現代 Haskell 要求你講清楚(`stock` 給前者、`newtype` 給後者)。
第 3 級還會學到第三種 `deriving via`。

### 裸 `deriving` 的歧義是怎麼來的

Haskell 98 只有一種 deriving:編譯器對 `Eq`、`Ord`、`Show` 等幾個固定的 class
有內建演算法(現在叫 `stock`)。後來 GHC 加了 `GeneralizedNewtypeDeriving`(GND):
newtype 和底層型別在執行期一模一樣,那底層型別的**任何** instance 都可以直接借來用,
例如 `newtype Gold = Gold Int deriving (Num)`—— `stock` 不會推 `Num`,但借 `Int` 的就行。

問題來了:`newtype Gold = Gold Int deriving (Show)` 到底是 stock(印 `Gold 3`)
還是 GND(印 `3`)?GHC 的規則是「能 stock 就 stock,不然試 GND」,
但這條規則沒寫在你的程式碼裡,讀的人猜不到,而且加一個擴充(`DeriveAnyClass`)之後規則又變。
`DerivingStrategies`(GHC 8.2)就是為了終結猜測:**你自己說**。
GHC2024 把它收進預設語言,代表社群已把「標策略」視為標準寫法。

```haskell
ghci> newtype Gold  = Gold  Int deriving stock   (Show)
ghci> newtype Gold2 = Gold2 Int deriving newtype (Show)
ghci> Gold 3
Gold 3
ghci> Gold2 3
3
```

舊教材、舊函式庫全是裸 `deriving (Eq, Show)`,讀到時記得它等於 `deriving stock`
(對 `data`)或「GHC 幫你猜」(對 `newtype`)。

## Semigroup 與 Monoid:可合併的東西

這對 class 到處都是,值得第一天就認識:

```haskell
class Semigroup a where
  (<>) :: a -> a -> a

class Semigroup a => Monoid a where
  mempty :: a
```

### Laws 全文

class 定義只規定型別,**laws** 規定行為。這兩個 class 的 laws 一共三條:

```haskell
-- Semigroup:結合律
(a <> b) <> c == a <> (b <> c)

-- Monoid:左單位元、右單位元
mempty <> a == a
a <> mempty == a
```

例子:list(`++`、`[]`)、`Text`(串接、`""`)、
`Map`、以及你的遊戲型別:

```haskell
instance Semigroup Gold where
  Gold a <> Gold b = Gold (a + b)

instance Monoid Gold where
  mempty = Gold 0
```

有了 Monoid,聚合就是一行:

```haskell
totalPrice :: [Item] -> Gold
totalPrice = foldMap (.price)    -- 取出每個價格,用 <> 全部合併
```

### 違反 law 會發生什麼:一個反例

編譯器**不檢查** laws —— 型別對就能編過。所以要親眼看一次違反的後果。
用減法做一個 Semigroup:

```haskell
newtype Diff = Diff Int deriving stock (Eq, Show)
instance Semigroup Diff where Diff a <> Diff b = Diff (a - b)
instance Monoid Diff where mempty = Diff 0
```

型別完全正確。但減法沒有結合律,`0` 也只是右單位元不是左單位元:

```haskell
ghci> a = Diff 10; b = Diff 3; c = Diff 2
ghci> ((a <> b) <> c, a <> (b <> c))
(Diff 5,Diff 9)                              -- 結合律破了
ghci> (mempty <> a, a <> mempty)
(Diff (-10),Diff 10)                         -- 左單位元破了
ghci> (foldr (<>) mempty [a, b, c], foldl' (<>) mempty [a, b, c])
(Diff 9,Diff (-15))                          -- 同一個 list,fold 方向不同答案不同
ghci> mconcat [a, b, c]
Diff 9
```

`mconcat`、`foldMap`、`Map.unionsWith`、第 2 級的 `traverse_`……base 裡所有吃 Monoid 的函式
都**沒有承諾**用哪個方向、哪種括號結合,它們的正確性建立在「反正結果一樣」上。
laws 一破,這些函式的回傳值就取決於實作細節,換個版本的 base 答案就變。

反過來說:只要 laws 成立,`foldMap` 可以自由地改成平行分段合併、
`mconcat` 可以改用任何順序,你的程式不用動。**Laws 是抽象能重構的保證**。

**Laws(定律)不是裝飾**:這是 Haskell 教學的核心方法 ——
class 的意義由型別+laws 定義,不靠比喻。(第 2 級教 Functor/Monad 時同樣如此:
它們不是 burrito,就是一組帶 laws 的 API。)本章測試裡直接驗證了你的 Monoid laws。

## 語意比較:和 OOP interface 的差別

- instance 可以事後補:別人的型別 + 你的 class 也能寫 instance。
- dispatch 依**型別**而非執行期物件 —— `mempty :: Gold` 沒有任何「物件」存在。
- 一個型別對一個 class 只能有一個 instance(全域一致性)。

## 你會看到的錯誤訊息

**忘了 deriving:**

```
Ch5.hs:4:8: error: [GHC-39999]
    • No instance for ‘Show Element’ arising from a use of ‘print’
```

`print` 需要 `Show`,你的型別沒有。修法:`deriving stock (Show)`。
同樣句型的 `No instance for ‘Eq Element’` 來自 `==`,`No instance for ‘Ord ...’` 來自 `sort`/`Map` 的 key。

**回傳型別多載沒人決定:**

```haskell
main = print mempty
```

```
Ch5b.hs:3:14: error: [GHC-39999]
    • Ambiguous type variable ‘a0’ arising from a use of ‘mempty’
      prevents the constraint ‘(Monoid a0)’ from being solved.
      Probable fix: use a type annotation to specify what ‘a0’ should be.
```

`mempty` 的型別完全由**用它的地方**決定,而 `print` 接受任何 `Show`,
所以沒人知道你要哪個 Monoid 的 `mempty`。`Ambiguous type variable` 幾乎永遠是這個原因:
一個「由回傳型別決定行為」的東西(`mempty`、`minBound`、`read`、下一章的字串字面值)
沒有被固定。修法:標型別 `print (mempty :: Gold)`。

## ghci 實驗

```haskell
ghci> :i Semigroup           -- 看 class 定義與所有 instance(list、Maybe、tuple、函式……)
ghci> :t (<>)                -- (<>) :: Semigroup a => a -> a -> a
ghci> :t foldMap             -- (Foldable t, Monoid m) => (a -> m) -> t a -> m
ghci> "abc" <> "def"
"abcdef"
ghci> mconcat ["a", "b", "c"]
"abc"
ghci> mempty :: String
""
```

`:i Semigroup` 的輸出很長,值得掃一眼:`(a, b)`、`a -> b`、`Maybe a`、`IO a` 都是 Semigroup,
只要它們的內容物是。這種「組合型別自動繼承性質」是 Monoid 無所不在的原因。

## 常見誤區

1. `deriving (Show)` 不標策略:對 `data` 沒事,對 `newtype` 你要自己猜 GHC 選哪個。
2. 寫了 `Semigroup` instance 但沒證明結合律 → 本章測試會抓到,實務上抓不到。
3. `Monoid` 沒有 `Semigroup` 就不能寫:`class Semigroup a => Monoid a` 是超類約束。
4. `Ambiguous type variable` 是「沒人決定型別」,不是「型別錯」;加標註。
5. 以為 instance 是「物件的方法」:`mempty` 沒有接收者,它靠回傳型別 dispatch。

## 2026 實務準則

1. deriving 永遠標策略;`data` 用 `stock`,`newtype` 借底層行為用 `newtype`。
2. 自己寫的 Semigroup/Monoid instance,在測試裡用 property test 驗 laws(第 2 級教)。
3. 遇到「一堆同型別的值要合起來」,先想 `foldMap`,不要手寫遞迴。

## 習題

`exercises/Exercises/E05Classes.hs` → `cabal test level01-foundations`

測試裡直接驗證了你的 Monoid laws。
