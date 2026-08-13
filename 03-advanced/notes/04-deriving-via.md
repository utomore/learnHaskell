# 第 4 章 — DerivingVia:instance 的複用

## 四種 deriving 策略(先總覽)

```haskell
newtype Level = Level Int
  deriving stock    (Eq, Show)   -- GHC 內建演算法,對「結構」生成
  deriving newtype  (Num, Ord)   -- 直接借底層型別(Int)的 instance
  deriving anyclass (ToJSON)     -- 空 instance,交給 default methods(小心用)
```

- `stock`:`Show (Level 3)` 印 `Level 3`(照結構)。
- `newtype`:`Show` 若用 newtype 策略會印 `3`(完全借 Int 的行為)。
  同一個 class 選錯策略行為就不同 —— **永遠明寫策略**,這也是本課程
  一直 `deriving stock` 的原因。

## 問題:同一套 instance 邏輯寫 N 次

遊戲裡一堆「合併就是相加」的型別:金幣、傷害、經驗值……

```haskell
instance Semigroup Gold where Gold a <> Gold b = Gold (a + b)
instance Monoid Gold where mempty = Gold 0
-- Damage、Xp、Score……全部再抄一次?
```

`Data.Semigroup` 早就有語義載體:`Sum`(相加)、`Max`(取大)、
`Min`、`Any`、`All`。缺的只是「借用它們的 instance」的方法。

## DerivingVia:指名道姓地借

`DerivingVia` 不在 GHC2024 內,需要開:

```haskell
{-# LANGUAGE DerivingVia #-}
import Data.Semigroup (Max (..), Sum (..))

newtype Gold = Gold Int
  deriving stock (Eq, Show)
  deriving (Semigroup, Monoid) via Sum Int   -- 「行為跟 Sum Int 一樣」

newtype HighScore = HighScore Int
  deriving stock (Eq, Show)
  deriving (Semigroup, Monoid) via Max Int   -- 排行榜:取大
```

原理:`Gold`、`Sum Int`、`Int` 的執行期表示**完全相同**,
GHC 用零成本的 `coerce` 把 `Sum Int` 的 instance 安全搬給 `Gold`。
一行宣告 = 一組 laws 齊全的 instance,而且語義寫在臉上。

## 自己當載體:寫一次,借 N 次

載體不限標準庫。定義「相加但封頂 100」的語義:

```haskell
newtype Capped = Capped Int          -- 專門當 via 載體
instance Semigroup Capped where
  Capped a <> Capped b = Capped (min 100 (a + b))
instance Monoid Capped where mempty = Capped 0

newtype Rage    = Rage Int    deriving (Semigroup, Monoid) via Capped
newtype Stamina = Stamina Int deriving (Semigroup, Monoid) via Capped
```

instance 邏輯(以及它該滿足的 laws)只存在一個地方。

## 2026 實務準則

1. 永遠明寫 deriving 策略;`anyclass` 只給真的有 default 全套的 class。
2. newtype 的 Semigroup/Monoid 幾乎都該 `via` 標準載體,不手寫。
3. 同一套 instance 邏輯出現第二次 → 抽成 via 載體。

## 習題

`exercises/Exercises/E04DerivingVia.hs` —— `Gold`(via Sum)、
`HighScore`(via Max)、自訂載體 `Capped` 與借用它的 `Rage`。
