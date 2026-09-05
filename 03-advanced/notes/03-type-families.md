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

我們需要的是:class 的每個 instance 可以**自己說**「我的元素型別是什麼」。
換句話說,需要一個從 `c` 算出元素型別的**型別層級函式**。

## 來龍去脈:functional dependencies → type families

這個需求 2000 年就有人解過。Mark Jones 在 *Type Classes with Functional
Dependencies*(ESOP 2000)提出 **fundeps**:多參數 class 加上
「c 決定 e」的註記:

```haskell
{-# LANGUAGE FunctionalDependencies #-}

class Container c e | c -> e where      -- 「知道 c 就知道 e」
  emptyC  :: c
  insertC :: e -> c -> c

instance Container [a]    a
instance Container IntSet Int
```

它能用,GHC 到今天仍支援,`mtl` 的 `MonadState s m | m -> s` 就是它。
問題出在**心智模型**:fundep 是「關係」而不是「函式」——
你在型別簽名裡**寫不出** `e`,只能多帶一個型別變數再靠約束把它綁住
(`fromListC :: Container c e => [e] -> c`)。class 一多,約束裡到處都是
只為了「被決定」而存在的變數,錯誤訊息則是一串 `Could not deduce`。

2005 年的論文 *Associated Types with Class*(Chakravarty、Keller、
Peyton Jones)換了個角度:既然要的是「從 c 算出 e」,那就**直接讓它是
型別層級的函式**。GHC 6.8/6.10(2007–2008)落地為 `TypeFamilies`。
從此 `Elem c` 可以直接寫在簽名裡,像呼叫函式一樣。

fundeps 你會在 `mtl`、`lens` 的舊 API、2010 年前的教材裡看到,
**識讀即可**;新程式碼用 type families。

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

## Type family 的三種形態

### 1. Associated(掛在 class 上)

上面那種。適合「這個型別函式的意義離不開某個 class」。

### 2. Open(獨立宣告,各處補 instance)

```haskell
type family Elem c :: Type          -- 只宣告,沒有等式
type instance Elem [a]    = a       -- 任何模組都能補
type instance Elem IntSet = Int
```

和 associated type 的能力相同,只是不綁 class;
函式庫作者想讓使用者為自己的型別擴充時用它。

### 3. Closed(所有等式寫在一起,由上而下比對)

```haskell
type family Loot (rank :: Rank) :: Type where
  Loot 'Boss   = (Gold, Equipment)
  Loot 'Normal = Gold
```

GHC 7.8(2014)加入。分支**有順序**,像 pattern matching;
外部**不能再加等式**,所以 GHC 可以做更多推理(例如知道
`Loot r` 不是 `Boss` 就一定是 `Normal`)。
搭配上一章的 DataKinds/GADT,可以讓「打倒不同等級的怪,
掉落物型別不同」這件事由編譯器擔保。

**取捨**:對應表的鍵是封閉集合(DataKinds 標籤)→ closed;
要讓別人擴充 → open 或 associated。

### 順帶一提:data family

`type family` 算出的是**既有**型別;`data family` 則是為每個索引
**宣告一個新的**資料型別(可以有不同的記憶體佈局):

```haskell
data family Vec a
newtype instance Vec Int  = VInt [Int]
data    instance Vec Bool = VBool Int Integer    -- bitset 表示法
```

`vector` 套件的 unboxed 向量就是這樣做到「`Vector Int` 和
`Vector Bool` 底層長得完全不同」。2026 日常很少自己寫,認得就好。

## 你會看到的錯誤訊息

### 「Elem c」沒有算出你以為的東西

```haskell
bad :: [Int]
bad = fromListC ["a", "b"]
```

```
P3Mismatch.hs:15:18: error: [GHC-83865]
    • Couldn't match type ‘[Char]’ with ‘Int’
      Expected: Elem [Int]
        Actual: String
```

怎麼讀:`Expected: Elem [Int]` —— GHC **先不化簡**,把型別函式原樣
留在訊息裡,再告訴你它等於 `Int`(第一行)。看到 `Elem ...` 出現在
Expected/Actual,第一步就是在 ghci 用 `:kind!` 把它算出來對照。

### 型別函式不是單射:推不回去

```haskell
singleton :: Container c => Elem c -> c
singleton x = insertC x emptyC

useIt = singleton (3 :: Int)     -- 想要哪種容器?
```

```
P3Inj.hs:26:20: error: [GHC-83865]
    • Couldn't match expected type ‘Elem c0’ with actual type ‘Int’
      The type variable ‘c0’ is ambiguous
```

`Elem [Int] = Int`、`Elem IntSet = Int` —— 知道元素是 `Int`,
**推不出**容器是誰。這叫「型別函式沒有單射性(injectivity)」,
是 type family 和 fundep 最大的差別:fundep `c -> e` 是單向的關係,
type family 從結果反推同樣不行。修法:呼叫端寫 `(singleton 3 :: IntSet)`,
或用 `TypeApplications` 指定 `c`。

如果你設計的 type family **確實**是單射的(每個輸出對應唯一輸入),
`TypeFamilyDependencies`(GHC 8.0)可以告訴 GHC:

```haskell
type family Wrap a = r | r -> a          -- 「結果決定引數」
type instance Wrap Int  = Maybe Int
type instance Wrap Bool = Maybe Bool
```

寫了註記但等式不符,GHC 會擋:
`Type family equation violates the family's injectivity annotation`。
`Elem` 天生不是單射(`[Int]` 和 `IntSet` 都給 `Int`),所以不能標。

### 型別函式不能 partial application

```haskell
class Wrap (f :: Type -> Type)
instance Wrap Elem       -- 想把 Elem 當高階型別傳
```

```
P3Partial.hs:7:10: error: [GHC-27346]
    • The type family ‘Elem’ should have 1 argument, but has been given none
```

type family 必須**吃飽引數**才是型別;`Maybe`、`[]` 這種 type constructor
可以只給一半,type family 不行。設計 API 時要記得這個限制
(想繞過去要用 `newtype` 包一層或 defunctionalization,屬於進階題)。

## ghci 實驗

```haskell
cabal repl level03-advanced
ghci> import Exercises.E03TypeFamilies
ghci> import Data.IntSet (IntSet)
ghci> :kind Elem
Elem :: * -> *
ghci> :kind! Elem IntSet
Elem IntSet :: *
= Int
ghci> :kind! Elem [Bool]
Elem [Bool] :: *
= Bool
ghci> :t insertC
insertC :: Container c => Elem c -> c -> c
```

`:kind!` 是 type family 的計算機:任何 `Couldn't match ... Elem ...`
都先來這裡把它展開。

## 跟 functional dependencies 的取捨

老程式碼會看到 `class Container c e | c -> e`(fundeps),表達力相近。
2026 的慣例:**新程式用 associated types** —— 型別函式的心智模型
更直接,錯誤訊息更好,和 DataKinds 生態整合更佳。fundeps 以識讀為主。

| | fundeps | type families |
|--|--|--|
| 心智模型 | class 參數之間的**關係** | 型別層級的**函式** |
| 簽名裡能寫 `Elem c` 嗎 | 不能,要多帶變數 | 能 |
| 從結果反推 | 靠 `c -> e` 方向 | 預設不行,`TypeFamilyDependencies` 可標 |
| 主要出現在 | `mtl`、2010 前的程式碼 | 2026 的新程式碼 |

## 常見誤區

1. 把 type family 當作可以反推的對應表 → 它是函式,不是雙射。
2. 忘了 `{-# LANGUAGE TypeFamilies #-}`(不在 GHC2024 內)。
3. 在 closed family 裡把泛用分支寫在特定分支**前面** → 後面永遠比不到。
4. 看到 `Expected: Elem [Int]` 就慌 → 先 `:kind!` 算出來。
5. 想把 type family 當高階型別傳 → 不行,要吃飽引數。

## 2026 實務準則

1. class 抽象碰到「單型容器」(IntSet、Text、ByteString)→ associated type。
2. 型別層級的對應表(rank → 掉落物、格式 → 解析結果)→ closed family。
3. 型別函式**不能 partial application**,設計 API 時記得這個限制。
4. 需要反推時,先想清楚它真的是單射嗎;是就標 `TypeFamilyDependencies`,
   不是就讓呼叫端用簽名或 `@` 指定。

## 習題

`exercises/Exercises/E03TypeFamilies.hs` —— 為 `[a]`、`IntSet`、`Text`
實作 `Container`(associated type),再寫泛型的 `fromListC`。
