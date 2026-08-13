# 第 3 章 — Type families:型別層級的函式

## 問題:IntSet 裝不進 Container class

想抽象「可以插入元素的容器」:

```haskell
class Container (c :: Type -> Type) where   -- 以為容器都長 c a
  insertC :: a -> c a -> c a
```

`[a]`、`Set a` 都符合。但 `IntSet` **沒有型別參數** ——
它是為 `Int` 特化的單型容器(更快更省),塞不進 `c :: Type -> Type` 的框。
`Text` 也一樣:它是字元容器,型別卻只是 `Text`。

## Associated type:讓 instance 自己宣告元素型別

`TypeFamilies` 不在 GHC2024 內,需要開:

```haskell
{-# LANGUAGE TypeFamilies #-}

class Container c where
  type Elem c :: Type          -- 每個 instance 給的「型別層級欄位」
  emptyC  :: c
  insertC :: Elem c -> c -> c
  toListC :: c -> [Elem c]

instance Container [a]    where type Elem [a]    = a
instance Container IntSet where type Elem IntSet = Int
instance Container Text   where type Elem Text   = Char
```

`Elem` 是一個**型別函式**:給它 `IntSet` 它回 `Int`。
class 方法的簽名裡可以使用它,所以 `insertC` 對 `[a]` 是
`a -> [a] -> [a]`,對 `IntSet` 自動變成 `Int -> IntSet -> IntSet`。

用的時候完全泛型:

```haskell
fromListC :: Container c => [Elem c] -> c
fromListC = foldr insertC emptyC
```

## Closed type family:獨立的型別函式

不掛在 class 上也可以定義,分支由上而下比對、封閉不可擴充:

```haskell
type family Loot (rank :: Rank) :: Type where
  Loot 'Boss   = (Gold, Equipment)
  Loot 'Normal = Gold
```

搭配上一章的 DataKinds/GADT,可以讓「打倒不同等級的怪,
掉落物型別不同」這件事由編譯器擔保。

## 跟 functional dependencies 的取捨

老程式碼會看到 `class Container c e | c -> e`(fundeps),表達力相近。
2026 的慣例:**新程式用 associated types** —— 型別函式的心智模型
更直接,錯誤訊息更好,和 DataKinds 生態整合更佳。fundeps 以識讀為主。

## 2026 實務準則

1. class 抽象碰到「單型容器」(IntSet、Text、ByteString)→ associated type。
2. 型別層級的對應表(rank → 掉落物、格式 → 解析結果)→ closed family。
3. 型別函式**不能 partial application**,設計 API 時記得這個限制。

## 習題

`exercises/Exercises/E03TypeFamilies.hs` —— 為 `[a]`、`IntSet`、`Text`
實作 `Container`(associated type),再寫泛型的 `fromListC`。
