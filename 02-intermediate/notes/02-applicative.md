# 第 2 章 — Applicative:多個上下文的值組合起來

## Functor 的極限

`fmap` 只能套**一元**函式。想把「兩個都可能失敗的值」餵給二元函式呢?

```haskell
ghci> fmap (+) (Just 3)
Just (+3) :: Maybe (Int -> Int)   -- 卡住了:函式被關在 Maybe 裡
```

Applicative 補上這一步:

```haskell
class Functor f => Applicative f where
  pure  :: a -> f a                  -- 把純值放進最小上下文
  (<*>) :: f (a -> b) -> f a -> f b  -- 套用「上下文裡的函式」
```

## 舊做法 → 新做法:為什麼會有這一層

**歷史**:Haskell 1.3(1996)只有 `Functor` 和 `Monad`,中間沒有東西。
要組合兩個 `Maybe`,當年的寫法是直接上 `Monad`:

```haskell
-- 1996–2014 的寫法:用 do 組合彼此獨立的值
addMaybe mx my = do
  x <- mx
  y <- my
  return (x + y)
```

2008 年 McBride 與 Paterson 的論文 *Applicative programming with effects*
指出:這段程式碼**根本沒用到 Monad 的能力**——`y` 的計算不依賴 `x`。
用 `Monad` 表達它,等於用大砲打鳥,而且把「這兩個值彼此獨立」
這條資訊丟掉了。`Applicative` 就是為這種「獨立組合」量身打造的抽象。

但它進標準庫的路很慢:`Applicative` 直到 **GHC 7.10(2015)**
才成為 `Monad` 的 superclass(所謂 AMP,Applicative-Monad Proposal)。
所以你在舊碼與舊教材裡會看到這些痕跡:

| 你看到的 | 原因 | 2026 寫法 |
|---|---|---|
| `return` | AMP 之前 `Monad` 有自己的 `return`,`pure` 屬於獨立的 `Applicative` | 一律 `pure`(`return` 現在只是 `pure` 的別名,留著相容) |
| `instance Monad Foo` 前面多一段 `instance Applicative Foo where pure = return; (<*>) = ap` | 2015 年為了讓舊碼編過的樣板 | 先寫 Applicative,Monad 建在它上面 |
| `mapM`、`sequence`、`liftM2` | 是 `traverse`、`sequenceA`、`liftA2` 的 Monad 專用舊版 | 用 Applicative 版,約束更弱、能用的地方更多 |
| 教材從 Functor 直接跳到 Monad | 2015 年前的教學順序 | Functor → Applicative → Monad |

## 套路:`f <$> x <*> y <*> z`

```haskell
ghci> (+) <$> Just 3 <*> Just 4
Just 7
ghci> (+) <$> Just 3 <*> Nothing
Nothing                            -- 任何一個失敗,全體失敗
```

拆開來看:`(+) <$> Just 3` 是 `Just (+3)`(第 1 章的 fmap),
再用 `<*>` 把關在 `Maybe` 裡的函式套到 `Just 4` 上。
這個鏈可以無限接下去 —— n 個參數的建構子照樣用:

```haskell
mkHero :: Text -> Int -> Either Text Hero
mkHero n h = Hero <$> validateName n <*> validateHp h
```

這是實務中**最常見的 Applicative 用法**:驗證多個欄位、組合多個解析結果。
`liftA2 f x y`(Prelude 內建)等價於 `f <$> x <*> y`。

### 順手常用:`<*` 與 `*>`

```haskell
(<*) :: f a -> f b -> f a    -- 兩邊都跑,留左邊的值
(*>) :: f a -> f b -> f b    -- 兩邊都跑,留右邊的值
```

```haskell
ghci> Just 1 <* Just 2
Just 1
ghci> Just 1 *> Just 2
Just 2
ghci> Right 1 <* (Left "e" :: Either String Int)
Left "e"                           -- 值來自左邊,但右邊失敗照樣失敗
```

解析器裡到處是它:`token <* spaces`(吃掉空白但不要它的值)。
IO 裡 `*>` 和 `>>` 幾乎同義。

## Laws

```haskell
pure id <*> v == v                              -- identity
pure f <*> pure x == pure (f x)                 -- homomorphism
u <*> pure y == pure ($ y) <*> u                -- interchange
pure (.) <*> u <*> v <*> w == u <*> (v <*> w)   -- composition
```

白話:

1. **identity**:「把 `id` 放進上下文再套用」什麼都不改——`pure` 真的是「最小上下文」,不夾帶效果。
2. **homomorphism**:兩個純值在上下文裡套用 = 先套用再放進去。`pure` 與 `<*>` 不會偷偷產生效果。
3. **interchange**:套用的順序可以翻轉,效果不變——效果只取決於「有哪些」,不取決於「誰先寫」。
4. **composition**:`<*>` 是結合的,所以長鏈怎麼加括號都一樣。

外加一條與 Functor 的相容條件:`fmap f x == pure f <*> x`。
四條 law 合起來的意思:**組合不會偷偷改變結構,`pure` 是中性的**。

### 違反 law 會怎樣

自己寫一個「記錄用了幾次 `<*>`」的 Applicative,`pure` 不小心從 1 起算:

```haskell
newtype Counted a = Counted (Int, a) deriving stock Show

instance Functor Counted where
  fmap f (Counted (n, a)) = Counted (n, f a)

instance Applicative Counted where
  pure a = Counted (1, a)                            -- 應該是 0
  Counted (n, f) <*> Counted (m, a) = Counted (n + m, f a)
```

```haskell
ghci> pure id <*> Counted (0, 'x')
Counted (1,'x')                    -- 違反 identity:多了一個 1
ghci> traverse (\x -> Counted (0, x)) "abc"
Counted (1,"abc")                  -- 三個 0 相加竟然是 1
```

第二行是真正的傷害:`traverse`(第 4 章)內部用 `pure` 起頭,
它相信 `pure` 是中性的。你的計數器從此多算一次,而 bug 在 `traverse` 裡
「看起來」,實際在 instance 裡。把 `pure a = Counted (0, a)` 改回來,
兩條都正常。

## Either 是 fail-fast

`Either e` 的 Applicative 遇到第一個 `Left` 就停:

```haskell
ghci> mkHero "" 999
Left "名字不能為空"     -- 只回報第一個錯
```

### Applicative 能做、Monad 做不到的事:`Validation`

想**收集所有錯誤**(表單驗證那種需求),自己寫一個型別只要十行:

```haskell
data Validation e a = Failure e | Success a
  deriving stock Show

instance Functor (Validation e) where
  fmap _ (Failure e) = Failure e
  fmap f (Success a) = Success (f a)

instance Semigroup e => Applicative (Validation e) where
  pure = Success
  Failure e1 <*> Failure e2 = Failure (e1 <> e2)   -- 兩邊都錯:累積
  Failure e1 <*> Success _  = Failure e1
  Success _  <*> Failure e2 = Failure e2
  Success f  <*> Success a  = Success (f a)
```

```haskell
ghci> Hero <$> validateName "" <*> validateHp 0
Failure ["名字不能為空","HP 必須在 1..999"]     -- 兩個錯都拿到
ghci> Hero <$> validateNameE "" <*> validateHpE 0   -- Either 版
Left "名字不能為空"                              -- 只有第一個
```

`Validation` **沒有合法的 Monad instance**:`>>=` 必須拿到左邊的值才能決定
右邊做什麼,左邊失敗時右邊根本不存在,自然收集不到第二個錯誤。
Applicative 的兩邊彼此獨立,所以可以兩邊都跑完再合併。
這正是「能力越弱、能做的事反而越多」的具體例子。
實務上用 `validation-selective` 套件,原理就是上面這幾行。

## Applicative vs Monad(下一章)

- Applicative:各個值**彼此獨立**,結構是靜態的 —— `x` 失敗與否不影響 `y` 怎麼算。
- Monad:下一步**依賴前一步的結果**(`>>=` 把值餵進去決定後續)。

經驗法則:能用 Applicative 就用 Applicative,表達的依賴關係最少、
最容易讀(也給了函式庫平行化/靜態分析的空間——
`mapConcurrently` 能平行就是因為 `traverse` 只要求 Applicative)。

## 你會看到的錯誤訊息

`<*>` 右邊忘了包進上下文:

```haskell
y :: Maybe Int
y = (+) <$> Just 3 <*> 4
```

```
E2.hs:3:24: error: [GHC-39999]
    • No instance for ‘Num (Maybe Int)’ arising from the literal ‘4’
    • In the second argument of ‘(<*>)’, namely ‘4’
      In the expression: (+) <$> Just 3 <*> 4
  |
3 | y = (+) <$> Just 3 <*> 4
  |                        ^
```

怎麼讀:`<*>` 右邊要的是 `Maybe Int`,你給了字面值 `4`,
GHC 只好嘗試把 `4` 當成 `Maybe Int`(數字字面值是多載的,
所以它去找 `Num (Maybe Int)` 的 instance),當然找不到。
修法:`<*> Just 4` 或 `<*> pure 4`。

規律:**每個 `<*>` 的兩邊都必須在同一個 `f` 裡**。看到 `No instance for Num (f ...)`
就檢查哪個引數忘了 `pure`。

## ghci 實驗

```haskell
ghci> Just (+3) <*> Just 4
Just 7
ghci> (,) <$> [1,2] <*> "ab"          -- list 的 Applicative:全部組合
[(1,'a'),(1,'b'),(2,'a'),(2,'b')]
ghci> pure 3 :: [Int]
[3]
ghci> pure 3 :: Maybe Int
Just 3
ghci> :t liftA2
liftA2 :: Applicative f => (a -> b -> c) -> f a -> f b -> f c
```

`pure 3` 的結果由**你要的型別**決定——這是「最小上下文」的意思:
list 的最小上下文是單元素、`Maybe` 是 `Just`、`IO` 是「不做任何事」。

## 常見誤區

- **鏈的第一個用 `<*>` 而不是 `<$>`。** `f <*> x` 要求 `f` 已經在上下文裡;
  普通函式起頭一律 `f <$> x <*> y`。
- **以為 `<*>` 有先後順序上的依賴。** 沒有。`y` 不知道 `x` 算出什麼,
  需要知道就是 Monad 的事。
- **忘記 `pure` 不帶效果。** `pure x` 在 `Either` 裡永遠是 `Right`、
  在 IO 裡不做任何 IO——law 保證。
- **在 `Validation` 上找 `>>=`。** 找不到是設計,不是缺陷。

## 習題

`exercises/Exercises/E02Applicative.hs` → `cabal test level02-intermediate`

其中 `mkHero` 用 `Either`;做完可以自己把它改成 `Validation` 版試試,
看 `mkHero "" 999` 的輸出怎麼變。
