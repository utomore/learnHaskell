# 第 5 章 — Optics:巢狀資料的存取器

## 問題:巢狀 record 更新很痛

```haskell
data Stats = Stats { hp :: Int, mp :: Int }
data Hero  = Hero  { name :: Text, stats :: Stats }
```

讀很舒服(`OverloadedRecordDot`):`hero.stats.hp`。
但**改**就原形畢露:

```haskell
takeDamage n hero = hero { stats = hero.stats { hp = hero.stats.hp - n } }
```

兩層就這樣,三層直接沒法看。optics(lens 家族)就是解這題的。

### 來龍去脈:從 getter/setter pair 到 van Laarhoven

最直覺的做法是一個 record 裝 getter 和 setter:

```haskell
data Lens s a = Lens { get :: s -> a, put :: s -> a -> s }
```

2000 年代的 `data-accessor`、`fclabels` 就是這樣。問題:**合成要手寫**
(`compose (Lens g1 p1) (Lens g2 p2) = Lens (g2 . g1) (\s a -> p1 s (p2 (g1 s) a))`),
而且 lens、traversal、prism 各是一個不相干的型別,彼此不能用同一個 `.` 串。

2009 年 Twan van Laarhoven 在部落格發現:**getter 和 setter 可以壓縮成
一個函式**,而且那個函式的形狀讓「合成」剛好等於函式合成。
2012 年 Edward Kmett 把這個發現擴展成 `lens` 套件:lens、traversal、
prism、iso、fold 全部是同一種形狀的函式,只差 `Functor` 約束的強弱,
所以全部能用 `.` 合成。這就是本章要手刻的東西。

## Lens 不是魔法:一個型別,兩個小把戲

一個 lens = 「聚焦 s 裡的一個 a」。van Laarhoven 表示法:

```haskell
type Lens' s a = forall f. Functor f => (a -> f a) -> s -> f s
```

讀作:「給我一個對 a 動手腳的函式(包在任意 Functor 裡),
我還你對整個 s 動手腳的函式」。做一個 lens 只要 getter + setter:

```haskell
lens :: (s -> a) -> (s -> a -> s) -> Lens' s a
lens get put f s = put s <$> f (get s)
```

神奇的是,`view`(讀)和 `over`(改)是**選不同的 Functor** 變出來的:

```haskell
view l s   = getConst (l Const s)              -- Const:偷走 a,忽略改動
over l g s = runIdentity (l (Identity . g) s)  -- Identity:乖乖套用 g
```

`Const` 假裝要改、其實把焦點值帶出來;`Identity` 真的改。
整套 lens 就只是 `Functor` 的應用 —— Level 2 的抽象在這裡兌現。

### 把兩個 Functor 攤開看

```haskell
newtype Const a b = Const { getConst :: a }      -- 第二個參數是假的
instance Functor (Const a) where
  fmap _ (Const x) = Const x                     -- 什麼都不做,x 原封不動

newtype Identity a = Identity { runIdentity :: a }
instance Functor Identity where
  fmap g (Identity x) = Identity (g x)           -- 老老實實套用
```

### 手動展開一次 `view hpL (Stats 30 10)`

```haskell
view hpL s
= getConst (hpL Const s)                              -- view 的定義
= getConst (lens (.hp) (\st h -> st {hp = h}) Const s) -- hpL 的定義
= getConst (put s <$> Const (get s))                  -- lens 的定義,get = (.hp)
= getConst (put s <$> Const 30)                       -- get s = 30
= getConst (Const 30)                                 -- Const 的 fmap 忽略函式
= 30
```

關鍵一步是倒數第二行:`fmap` 對 `Const` 是 no-op,所以 setter 根本
沒被呼叫,30 直接被帶出來。`over` 走的是同一條路,只是 `Identity` 的
`fmap` 真的會把 `put s` 套上去。在 ghci 裡可以直接驗:

```haskell
ghci> getConst (hpL Const (Stats 30 10))
30
ghci> runIdentity (hpL (Identity . (+5)) (Stats 30 10))
Stats {hp = 35, mp = 10}
```

## 最強性質:lens 用 `.` 就能組合

lens 是普通函式,所以函式合成就是 lens 合成:

```haskell
statsL :: Lens' Hero Stats
hpL    :: Lens' Stats Int

heroHpL :: Lens' Hero Int
heroHpL = statsL . hpL              -- 一路聚焦進去

takeDamage n = over heroHpL (max 0 . subtract n)   -- 巢狀更新一行
```

注意方向和 record dot 一致:`statsL . hpL` ≈ `.stats.hp`,由外而內。
這和一般函式合成「由右往左」的直覺相反,原因是 lens 吃的是
「對內層動手腳的函式」,外層的 lens 在最外面接。

## Lens laws:三條定律

一個「合法」的 lens 要滿足:

```haskell
view l (set l a s) == a            -- 1. set 後 view,拿回設的值(你設的有效)
set l (view l s) s == s            -- 2. view 後 set 回去,什麼都沒變(沒有副作用)
set l b (set l a s) == set l b s   -- 3. 連設兩次,只有最後一次算數
```

違反的例子:`lens (.hp) (\st h -> st {hp = max 0 h})` —— setter 偷偷 clamp,
`set l (-5) s` 後 `view` 拿到 0 而不是 -5,第 1 條破了。clamp 應該放在
`over` 的函式裡(像 `takeDamage` 那樣),不該藏在 lens 裡。
測試裡的 hedgehog 性質就是在抽查第 1 條。

## 家族成員:Traversal 與 Prism

### Traversal:0..n 個焦點

把 `Functor` 換成 `Applicative`,一個 lens 就能同時聚焦多個位置:

```haskell
type Traversal' s a = forall f. Applicative f => (a -> f a) -> s -> f s

newtype Party = Party [Hero]

membersT :: Traversal' Party Hero
membersT f (Party hs) = Party <$> traverse f hs     -- 就是 Level 2 的 traverse!
```

它能和 lens 直接合成,一次更新全隊的 HP:

```haskell
ghci> over (membersT . statsL . hpL) (subtract 5) (Party [rin, rin])
Party [Hero {name = "Rin", stats = Stats {hp = 25, mp = 10}}, ...]
ghci> toListOf (membersT . statsL . hpL) (Party [rin, kai])
[30,12]
```

(`toListOf` 用 `Const [a]` 當 Functor,靠 list 的 Monoid 把所有焦點蒐集起來;
`over` 對 traversal 的定義和對 lens 一模一樣,因為 `Identity` 也是 Applicative。)

### Prism:sum type 的一個分支

lens 說「一定有一個 a」;prism 說「**可能**有一個 a,而且能從 a 反向組回 s」:

```haskell
data Loot = Coins Int | Item Text

preview _Coins (Coins 5)      -- Just 5
preview _Coins (Item "sword") -- Nothing
review  _Coins 7              -- Coins 7
```

van Laarhoven 形式的 prism 需要 profunctor,超出本章;
記住直覺即可:**lens 對 product type,prism 對 sum type**。

## 你會看到的錯誤訊息

### 合成方向反了

```haskell
heroHpL = hpL . statsL        -- 應該是 statsL . hpL
```

```
P5Order.hs:4:11: error: [GHC-83865]
    • Couldn't match type ‘Stats’ with ‘Hero’
      Expected: (Int -> f Int) -> Hero -> f Hero
        Actual: (Int -> f Int) -> Stats -> f Stats
    • In the first argument of ‘(.)’, namely ‘hpL’
```

怎麼讀:GHC 把 `Lens'` 展開了(`(Int -> f Int) -> Hero -> f Hero`),
看到 `s` 的位置對不上就知道是順序問題。**由外而內**,和 record dot 一樣。

### 拿 traversal 當 lens 用

```haskell
firstHp = view (membersT . statsL . hpL)
```

```
P5Trav.hs:5:17: error: [GHC-39999]
    • Could not deduce ‘Applicative f’ arising from a use of ‘membersT’
      from the context: Functor f
        bound by a type expected by the context: Lens' Party Int
```

`view` 只給 `Functor`(`Const a` 只在 `a` 是 Monoid 時才是 Applicative),
traversal 要 `Applicative`。訊息說得很準:缺 `Applicative f`。
修法:用 `toListOf` 取全部,或另外寫「取第一個」的 fold。

### 忘了 `(.hp)` 需要 OverloadedRecordDot

```
error: [GHC-83865]
    • Couldn't match type ‘Stats -> c0’ with ‘Hero’
      Expected: Hero -> Stats
        Actual: (Stats -> c0) -> Hero -> c0
    • In the first argument of ‘lens’, namely ‘(. stats)’
```

看到 `(. stats)`(中間有空格)就知道:GHC 把 `(.stats)` 讀成了
「`.` 運算子的 section」。本專案 cabal 已全域開 `OverloadedRecordDot`,
但在裸 `ghc`/ghci 裡跑片段時要 `:set -XOverloadedRecordDot`。

## 生態系識讀(2026)

| 套件 | 定位 |
|------|------|
| `optics` | 現代推薦:錯誤訊息好、API 分層清楚(`view`/`set`/`%`) |
| `lens` | 老大哥:功能最全、依賴大、錯誤訊息難讀 |
| `microlens` | 極小依賴,函式庫作者常用 |

它們的核心都是你這章手寫的東西。日常讀值用 record dot 就好;
optics 的主場是**巢狀更新**、以及 lens 之外的家族成員:
`Traversal`(0..n 個焦點,就是 `traverse`!)、`Prism`(sum type 的分支)。

### 為什麼 `lens` 的錯誤訊息惡名昭彰,而 `optics` 不會

`lens` 完全採用 van Laarhoven 表示:每個 optic **就是**一個 rank-2 函式。
好處是零依賴、`.` 直接能用;代價是型別錯誤時 GHC 看到的不是「Lens」,
而是展開後的 `(a -> f a) -> s -> f s`、`Profunctor p => p a (f b) -> ...`,
初學者很難從一屏的 `f`、`p` 裡讀出「你把 traversal 當 lens 用了」。

`optics`(Well-Typed,2019)把 optic 包進**抽象型別** `Optic k is s t a b`,
種類 `k` 是 DataKinds 標籤(`A_Lens`、`A_Traversal`、`A_Prism`……),
合成用 `%` 而不是 `.`,由型別層級的表格算出「lens % traversal = traversal」。
錯誤訊息因此能說出「A_Traversal 不能當 A_Lens 用」這種人話。
內部實作仍是 profunctor/van Laarhoven,你這章學的原理一點沒浪費。

## 用真套件:optics-core

原理懂了,現在看 2026 推薦的 `optics` 長什麼樣。本套件已經把
`optics-core` 加進 `build-depends`(`optics-core` 是核心;`optics` 套件
再包進 Template Haskell 的 `makeLenses` 與額外模組,教學用 core 就夠)。

```haskell
import Optics.Core

statsL :: Lens' Hero Stats
statsL = lens (.stats) (\h s -> h {stats = s})   -- lens 的簽名和你手刻的一模一樣

hpL :: Lens' Stats Int
hpL = lens (.hp) (\s v -> s {hp = v})

heroHp :: Lens' Hero Int
heroHp = statsL % hpL                            -- 合成用 %,不是 .
```

**唯一要重新適應的是 `%`。** 你手刻的 lens 是普通函式,所以能用 `.` 合成;
`optics` 刻意把 optic 做成抽象型別 `Optic k is s t a b`,不再是函式。
代價是要換一個合成運算子,換來的是錯誤訊息會直接說「這是 Lens、
那是 Traversal,你不能對 Traversal 用 view」,而不是 `lens` 那種
三行 `Functor f =>` 展開式。這就是 2019 年 `optics` 誕生的理由。

手刻版沒做到的兩個家族成員,`optics` 直接給你:

```haskell
-- Traversal:0..n 個焦點。traversed 走進 list 的每個元素。
bagPrices :: Traversal' Hero Int
bagPrices = bagL % traversed % priceL

discountAll :: Int -> Hero -> Hero
discountAll pct = over bagPrices (\p -> p - p * pct `div` 100)

bagValue :: Hero -> Int
bagValue = sumOf bagPrices                       -- 對 traversal 聚合:sumOf / toListOf

-- Prism:sum type 的一個分支。prism' 建構子 拆解器。
equippedP :: Prism' Slot Item
equippedP = prism' Equipped $ \case
  Equipped i -> Just i
  Bare -> Nothing

weaponName :: Hero -> Maybe Text
weaponName = preview (weaponL % equippedP % to (.label))   -- 可能沒有 → preview
```

實際跑起來(`cabal repl level03-advanced -f solutions`):

```haskell
ghci> import Exercises.E08OpticsLib
ghci> import Optics.Core
ghci> let rin = Hero "Rin" (Stats 30 5) [Item "axe" 100, Item "bow" 50] (Equipped (Item "sword" 10))
ghci> view heroHp (takeDamage 12 rin)
18
ghci> toListOf bagPrices (discountAll 10 rin)
[90,45]
ghci> weaponName rin
Just "sword"
ghci> weaponName rin {weapon = Bare}
Nothing
ghci> bagValue rin
150
```

### 讀舊碼的對照表:`lens` vs `optics`

| 動作 | `lens`(2012,函式式) | `optics`(2019,抽象型別) |
|------|------|------|
| 合成 | `statsL . hpL` | `statsL % hpL` |
| 讀 | `view l s` / `s ^. l` | `view l s` / `s ^. l`(在 `Optics.Operators`) |
| 改 | `over l f s` / `l %~ f` | `over l f s` / `l %~ f` |
| 設 | `set l v s` / `l .~ v` | `set l v s` / `l .~ v` |
| 0..n 焦點 | `toListOf` / `s ^.. l` | `toListOf` / `s ^.. l` |
| 分支 | `preview` / `s ^? p` | `preview` / `s ^? p` |
| 自動產生 | `makeLenses ''Hero`(TH) | `makeLenses ''Hero`(在 `optics-th`) |

函式名幾乎全部相同,真正差的只有合成運算子。所以「先學原理再看套件」
是對的順序:你已經會 90%。

一個小坑:`Optics.Core` 匯出一個叫 `Empty` 的 class,所以本章習題的
武器槽用 `Bare` 而不是 `Empty` 當建構子。遇到
`Ambiguous occurrence ‘Empty’` 就是這件事,改名或 `hiding (Empty)` 都行。

## ghci 實驗

```haskell
cabal repl level03-advanced
ghci> import Exercises.E05Optics
ghci> let rin = Hero "Rin" (Stats 30 10)
ghci> view (statsL . hpL) rin
30
ghci> set (statsL . hpL) 99 rin
Hero {name = "Rin", stats = Stats {hp = 99, mp = 10}}
ghci> :t statsL . hpL
statsL . hpL :: Functor f => (Int -> f Int) -> Hero -> f Hero
```

最後一行值得多看一眼:`Lens' Hero Int` 這個別名在 ghci 裡會被展開,
這就是你在錯誤訊息裡會看到的樣子。

## 常見誤區

1. 合成順序寫成「由內而外」→ `Couldn't match type ‘Stats’ with ‘Hero’`。
2. 在 lens 的 setter 裡塞業務邏輯(clamp、驗證)→ 破壞 laws;
   邏輯放 `over` 的函式裡。
3. `view` 一個 traversal → 缺 `Applicative`;要 `toListOf`。
4. 型別別名忘了 `forall f.` → `Not in scope: type variable ‘f’`。
5. 為了讀一個欄位去引 optics → record dot 就夠,optics 是給**更新**用的。

## 2026 實務準則

1. 讀值:record dot。巢狀更新:optics(或本章的手寫 lens)。
2. 新專案選 `optics`;讀舊碼要認得 `lens` 的 `^.` `%~` 符號。
3. getter/setter 定律:set 後 view 要拿回設的值 —— 測試會抽查。
4. lens 只做「聚焦」,不做業務邏輯。

## 習題

`exercises/Exercises/E05Optics.hs` —— 手刻迷你 lens 庫:
`lens`/`view`/`over`/`set`,做出 `statsL`、`hpL`,
用合成寫 `takeDamage`。

接著 `exercises/Exercises/E08OpticsLib.hs` —— 同一個領域改用 `optics-core`:
`lens`/`%`/`traversed`/`prism'`,做出 `bagPrices`(Traversal)、
`equippedP`(Prism),寫 `discountAll`、`bagValue`、`weaponName`。
測試裡有 lens 定律和 prism 定律的性質測試。
