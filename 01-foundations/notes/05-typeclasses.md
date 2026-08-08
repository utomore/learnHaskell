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

## Semigroup 與 Monoid:可合併的東西

這對 class 到處都是,值得第一天就認識:

```haskell
class Semigroup a where
  (<>) :: a -> a -> a          -- 結合律:(a <> b) <> c == a <> (b <> c)

class Semigroup a => Monoid a where
  mempty :: a                  -- 單位元:mempty <> x == x
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

**Laws(定律)不是裝飾**:結合律保證了合併順序無關,
所以 `foldMap` 未來甚至可以平行化。這是 Haskell 教學的核心方法 ——
class 的意義由型別+laws 定義,不靠比喻。(第 2 級教 Functor/Monad 時同樣如此:
它們不是 burrito,就是一組帶 laws 的 API。)

## 語意比較:和 OOP interface 的差別

- instance 可以事後補:別人的型別 + 你的 class 也能寫 instance。
- dispatch 依**型別**而非執行期物件 —— `mempty :: Gold` 沒有任何「物件」存在。
- 一個型別對一個 class 只能有一個 instance(全域一致性)。

## 習題

`exercises/Exercises/E05Classes.hs` → `cabal test level01-foundations`

測試裡直接驗證了你的 Monoid laws。
