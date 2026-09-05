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

親眼確認一次:

```haskell
ghci> newtype Level  = Level  Int deriving stock   (Show)
ghci> newtype Level2 = Level2 Int deriving newtype (Show)
ghci> show (Level 3)
"Level 3"
ghci> show (Level2 3)
"3"
```

### 來龍去脈:為什麼會有四種

- **stock**:Haskell 98 就有,只支援 `Eq`/`Ord`/`Show`/`Read`/`Enum`/`Bounded`
  等固定幾個 class,GHC 知道怎麼「照結構」生成。
- **newtype**(`GeneralizedNewtypeDeriving`,GHC 6.x 時代):newtype 和
  底層型別的記憶體表示完全相同,那 `Num Int` 的 instance 應該可以直接拿來
  當 `Num Level` 用。早期它的實作是「偷偷 unsafeCoerce」,
  2014 年 GHC 7.8 引入 **role** 系統之後才變成型別安全的(見下文 `coerce`)。
- **anyclass**(`DeriveAnyClass`,GHC 7.10):給有完整 default methods 的
  class(`ToJSON`、`NFData` 這類靠 `Generic` 提供預設實作的)寫一個
  **空 instance**。
- **via**(`DerivingVia`,GHC 8.6,2018 年論文 *Deriving Via: or, How to
  Turn Hand-Written Instances into an Anti-Pattern*):newtype deriving 的
  泛化 —— 不只能借「底層型別」的 instance,能借**任何表示相同的型別**的。

四種同時存在之後,裸的 `deriving (Show)` 變得有歧義(newtype 該用
stock 還是 newtype?GHC 有預設規則,但你記得住嗎),
所以 `DerivingStrategies` 進了 GHC2024,而 2026 慣例是永遠明寫。

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

## 原理:`coerce`、`Coercible` 與 role

```haskell
ghci> import Data.Coerce
ghci> :t coerce
coerce :: Coercible a b => a -> b
ghci> coerce (Sum 3 :: Sum Int) :: Gold
Gold 3
ghci> coerce [Gold 1, Gold 2] :: [Int]      -- 穿過 list,不用 map
[1,2]
```

`Coercible a b` 是 GHC 內建的約束:「a 和 b 在執行期長得一模一樣」。
newtype 和它的內容之間永遠成立;而且它會**穿透**型別建構子——
`[Gold]` 和 `[Int]` 也 Coercible。整個 `coerce` 在編譯後是**零指令**。

但穿透不是無條件的。看 `Map`:

```haskell
ghci> :i Map
type role Map nominal representational
```

每個型別參數有一個 **role**:
- **representational**:只看記憶體表示。`Map k Int` → `Map k Gold` 可以。
- **nominal**:名字不同就是不同型別。`Map Int v` → `Map Gold v` **不行**。

為什麼 key 是 nominal?`Map` 的內部結構靠 `Ord k` 排好,
`Gold` 的 `Ord` instance 可能跟 `Int` 不同(例如反過來排),
coerce 之後樹的排序就壞了。GHC 在 `Map` 的定義處推出「k 的 Ord 會影響
結構」,所以把 k 標成 nominal:

```
P4Nominal.hs:10:11: error: [GHC-18872]
    • Couldn't match type ‘Int’ with ‘Gold’
        arising from a use of ‘coerce’
```

上一章 `:i Expr` 看到的 `type role Expr nominal` 也是同一件事:
GADT 的索引是型別證據,不能換名字。

## 你會看到的錯誤訊息:representation 不同

```haskell
newtype Gold = Gold Int
  deriving (Semigroup) via Sum Double      -- Int 跟 Double 表示不同
```

```
P4Repr.hs:5:13: error: [GHC-18872]
    • Couldn't match representation of type ‘Int’ with that of ‘Double’
        arising from the coercion of the method ‘<>’
          from type ‘Sum Double -> Sum Double -> Sum Double’
            to type ‘Gold -> Gold -> Gold’
    • When deriving the instance for (Semigroup Gold)
```

怎麼讀:
- `Couldn't match representation`:不是型別不合,是**記憶體表示**不合。
  這個字眼一出現,幾乎都是 `coerce`/newtype deriving/via 的問題。
- `from type ... to type ...`:GHC 想把 `Sum Double` 版的 `<>` 搬成
  `Gold` 版,搬不動。
- 修法:via 的載體必須是「同一個底層型別再包幾層 newtype」——
  `Sum Int` 可以,`Sum Double` 不行。

## `deriving anyclass` 的陷阱(親手炸一次)

`anyclass` 給的是**空 instance**。對 `Show` 這種 class,
`show` 和 `showsPrec` 互相以對方為預設實作:

```haskell
{-# LANGUAGE DeriveAnyClass #-}
data Loot = Loot Int deriving anyclass Show
main = print (Loot 3)
```

編譯只給警告:

```
warning: [GHC-06201] [-Wmissing-methods]
    • No explicit implementation for
        either ‘showsPrec’ or ‘show’
```

執行**無限迴圈**,永遠印不出東西(`show` 呼叫 `showsPrec`,
`showsPrec` 呼叫 `show`……)。這就是為什麼:

1. `anyclass` 只給「有完整 default 全套」的 class(通常是靠 `Generic`
   的那些:`ToJSON`、`FromJSON`、`NFData`、`Hashable`)。
2. **把 `-Wmissing-methods` 當 error 看**。

`Generic`(GHC 內建的「用型別描述資料結構」機制)是 anyclass 能運作的
基礎:`deriving stock Generic` 之後,函式庫就能在不知道你的型別的情況下
寫出通用實作。Level 4 談 aeson 序列化時會細講。

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
論文標題說得直白:有了 via,**手寫 instance 應該是反模式** ——
每一個手寫的 `Semigroup` instance 都在問「這個語義為什麼不能是一個載體」。

## ghci 實驗

```haskell
cabal repl level03-advanced
ghci> import Exercises.E04DerivingVia
ghci> import Data.Semigroup
ghci> Gold 3 <> Gold 4
Gold 7
ghci> mconcat [HighScore 3, HighScore 9, HighScore 1]
HighScore 9
ghci> :i Gold                  -- 看得到 Semigroup/Monoid instance 是從 via 來的
ghci> :i Coercible             -- 內建 class,沒有 instance 清單,由 GHC 自動解
```

## 常見誤區

1. 裸 `deriving (Show)` 在 newtype 上 → 語義不明,永遠標策略。
2. `anyclass` 用在沒有完整 default 的 class → 執行期無限迴圈或 `undefined`。
3. via 的載體底層型別不同 → `Couldn't match representation`。
4. 想 `coerce` 過 `Map` 的 key、`Set` 的元素 → nominal role,不行;
   要 `Map.mapKeys` 或先設計成 `Map Int`。
5. 以為 `coerce` 有成本 → 沒有,它是編譯期的證明,執行期消失。

## 2026 實務準則

1. 永遠明寫 deriving 策略;`anyclass` 只給真的有 default 全套的 class。
2. newtype 的 Semigroup/Monoid 幾乎都該 `via` 標準載體,不手寫。
3. 同一套 instance 邏輯出現第二次 → 抽成 via 載體。
4. 看到 `Couldn't match representation` → 檢查底層型別;
   看到 `coerce` 過不去 → `:i` 看 role。

## 習題

`exercises/Exercises/E04DerivingVia.hs` —— `Gold`(via Sum)、
`HighScore`(via Max)、自訂載體 `Capped` 與借用它的 `Rage`。
