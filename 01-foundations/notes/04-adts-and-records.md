# 第 4 章 — 代數資料型別(ADT)與現代 Record

> 本章示範程式:`src/Examples/Adventure.hs`,開 `cabal repl` 跟著玩。

## 用型別描述你的領域

ADT 是 Haskell 建模的核心 —— 遊戲開發尤其如此:

```haskell
-- 列舉(sum type 最簡單的形式)
data Element = Fire | Ice | Lightning
  deriving stock (Eq, Show)

-- 每個建構子可以帶資料
data Monster
  = Slime Int             -- 史萊姆帶 HP
  | Dragon Element Int    -- 龍帶屬性與 HP
  deriving stock (Eq, Show)
```

「sum type」= 值是**其中一種**;「product type」= 值是**每個欄位都有**(record、tuple)。
兩者組合就叫**代數**資料型別。

為什麼叫「代數」?因為型別的**值有幾種**可以用加法和乘法算出來:
`Element` 有 3 個值;`Dragon Element Int` 有 3 × (Int 的個數) 個值;
`Monster` = Slime 的個數 **+** Dragon 的個數。sum 就是加、product 就是乘。
這個算術有實際用途:設計狀態型別時,算一下「合法狀態有幾種、型別能表達幾種」,
兩者不相等就代表有非法狀態混進來了。

處理 ADT 就是 pattern matching,編譯器會檢查你**沒漏掉任何案例** ——
新增一種怪物,所有忘記處理它的地方都會變成編譯警告。這是
「**把非法狀態變成無法表達**」(make illegal states unrepresentable)哲學的基礎。

```haskell
describeMonster :: Monster -> Text
describeMonster = \case          -- \case:直接對唯一引數做 case
  Slime hp -> ...
  Dragon el hp -> ...
```

`\case` 是 `LambdaCase` 擴充的語法,GHC2024 內建;它等於 `\x -> case x of`,
省掉一個只用一次的變數名。

### 對照:OOP 怎麼做同一件事

在 Java/C# 裡「怪物有很多種」會寫成一個 `Monster` 基底類別加子類別,
每種行為是子類別裡的一個方法。加一種**怪物**很容易(加一個子類別),
加一種**行為**很痛(每個子類別都要改)。ADT 剛好相反:加一種行為就是多寫一個函式,
加一種怪物要改所有函式 —— 但編譯器會把要改的地方全部列給你。
遊戲邏輯通常是「怪物種類固定、對怪物做的事一直在長」,ADT 的取捨正好合適。

## Record:2026 的寫法

```haskell
data Player = Player
  { name :: Text
  , hp :: Int
  , maxHp :: Int
  }
  deriving stock (Eq, Show)
```

搭配本專案在 cabal 的 `default-extensions` 裡**全域開啟**的三個擴充
(`OverloadedStrings`、`NoFieldSelectors`、`OverloadedRecordDot`),存取欄位用**點語法**:

```haskell
ghci> sampleHero.hp
100
ghci> sampleHero.name
"Hero"
```

自己開新專案時,把這三個擴充寫進 cabal 的 `default-extensions`(見第 9 章),
或在單檔程式的模組頂端寫 `{-# LANGUAGE NoFieldSelectors, OverloadedRecordDot #-}`。

- 建構與更新照舊:

```haskell
hero = Player {name = "Hero", hp = 100, maxHp = 100}

takeDamage :: Int -> Player -> Player
takeDamage dmg p = p {hp = max 0 (p.hp - dmg)}   -- 產生新值,不是就地修改
```

這個 `World -> World` 的更新模式,就是之後 game loop 每一幀在做的事。

### Record 的二十年:從 field selector 到點語法

Haskell 98 的 record 是這樣設計的:寫 `data Player = Player { hp :: Int }`,
編譯器會自動生成一個**頂層函式** `hp :: Player -> Int`,叫做 field selector。
讀欄位就是 `hp player`。看起來很合理,問題在「頂層」兩個字:

```haskell
data Player  = Player  { name :: Text, hp :: Int }
data Monster = Monster { name :: Text, hp :: Int }
```

```
Ch4b.hs:4:26: error: [GHC-29916]
    Multiple declarations of ‘name’
    Declared at: Ch4b.hs:3:26
                 Ch4b.hs:4:26
    Suggested fix:
      Perhaps you intended to use the ‘DuplicateRecordFields’ extension
```

兩個型別都想要 `name` 欄位,但同一個模組只能有一個頂層 `name` 函式。
於是十幾年間 Haskell 程式碼長出各種醜陋的規避法:`playerName`/`monsterName` 前綴、
`_name` 底線配 lens、每個型別一個模組……這被公認是 Haskell 最大的人體工學缺陷。

修補分三步:

1. **`DuplicateRecordFields`**(GHC 8.0,2016):允許同名欄位共存,但用 `name x`
   時 GHC 常常猜不出你要哪個型別的,錯誤訊息一堆 ambiguous。過渡期產物。
2. **`OverloadedRecordDot`**(GHC 9.2,2021):`x.name` 語法,由 `x` 的型別決定
   `name` 是哪個欄位,靠 `HasField` 這個 class 解析。問題終結。
3. **`NoFieldSelectors`**(GHC 9.2):既然有了點語法,乾脆**不要生成**頂層 selector 函式,
   `name`、`hp` 這些名字還給你當變數用,也不再污染模組命名空間。

三個一起開就是 2026 的標準配置。點語法目前只管**讀**;
**寫**還是用 `p {hp = ...}` 的傳統更新語法 —— 對應的 `OverloadedRecordUpdate`
仍是實驗性擴充,語法可能再變,先不要用。巢狀更新很痛的問題,第 3 級 optics 章解決。

你在舊程式碼會看到的三種讀法:`hp p`(Haskell 98 selector)、`p ^. hp`(lens)、
`p.hp`(現代)。前兩種讀得懂即可。

## newtype:零成本的型別包裝

```haskell
newtype Gold = Gold Int
```

執行期和 `Int` 完全相同(零開銷),但型別系統會阻止你把金幣加到 HP 上。
單位、ID、金額……都該包 newtype。第 5 章會配 deriving 一起用。

`newtype` 和「只有一個建構子、一個欄位的 `data`」差在哪?`data Gold = Gold Int`
在執行期多一層指標(box),而且多了一個值:`Gold undefined` 和 `undefined` 不同。
`newtype` 保證編譯後**完全消失**,兩者在執行期是同一個 `Int`。
規則很簡單:一個建構子一個欄位 → 一律 `newtype`。

## Maybe 與 Either 也只是 ADT

```haskell
data Maybe a    = Nothing | Just a
data Either e a = Left e  | Right a   -- 慣例:Left 放錯誤,Right 放成功
```

沒有魔法 —— 你在第 2 章用的 `Maybe` 自己就能定義。
`Either` 讓失敗帶原因,是之後錯誤處理章節的基石。

```haskell
ghci> :i Maybe
type Maybe :: * -> *
data Maybe a = Nothing | Just a
ghci> :k Maybe
Maybe :: * -> *
ghci> :k Maybe Int
Maybe Int :: *
```

`:k` 查的是 **kind**(型別的型別):`Maybe` 自己不是一個完整的型別,
它是「吃一個型別、吐一個型別」的型別建構子(`* -> *`),`Maybe Int` 才是完整的(`*`)。
現在只要認得這個記號;第 2 級的 Functor 就是定義在 `* -> *` 上的。

## 遞迴 ADT

型別可以指涉自己 —— 樹狀結構信手拈來:

```haskell
data Expr = Lit Int | Add Expr Expr | Mul Expr Expr | Neg Expr

eval :: Expr -> Int
eval = \case
  Lit n   -> n
  Add a b -> eval a + eval b
  ...
```

這是每個直譯器/傷害公式引擎/技能效果系統的骨架。
注意它和第 3 章的 list 一模一樣:`data [a] = [] | a : [a]` 也是遞迴 ADT,
`myLength` 的兩個案例就是 `eval` 的四個案例。

## 你會看到的錯誤訊息

**忘了本專案開著 `NoFieldSelectors`,用舊寫法讀欄位:**

```haskell
main = print (hp (Player "a" 1))
```

```
Ch4.hs:5:15: error: [GHC-88464]
    Variable not in scope: hp :: Player -> a0
    Suggested fix:
      Notice that ‘hp’ is a field selector belonging to the type ‘Player’
      that has been suppressed by NoFieldSelectors.
```

GHC 直接告訴你原因。修法:`(Player "a" 1).hp` 或先綁定 `p.hp`。

**record 更新漏了建構子**(`-Wincomplete-record-updates`,本專案已開):

```haskell
data Shape = Circle { radius :: Double } | Rect { w :: Double, h :: Double }
grow s = s { radius = 2 }
```

```
Ch4c.hs:5:10: warning: [GHC-62161] [-Wincomplete-record-updates]
    Pattern match(es) are non-exhaustive
    In a record update: Patterns of type ‘Shape’ not matched: Rect _ _
```

`Rect` 沒有 `radius` 欄位,對它做這個更新會在執行期炸
(`Non-exhaustive patterns in record update`)。教訓:**sum type 的各分支不要用 record 語法**,
欄位只放在 product type(單一建構子)上;需要的話讓每個分支帶一個自己的 record。

## ghci 實驗

```haskell
ghci> :t Just                 -- Just :: a -> Maybe a        (建構子就是函式)
ghci> :t Left                 -- Left :: a -> Either a b
ghci> data P = P { hp :: Int } deriving stock Show
ghci> :t (.hp)                -- (.hp) :: HasField "hp" r a => r -> a
ghci> p = P 3
ghci> p.hp
3
ghci> p { hp = 9 }
P {hp = 9}
```

`(.hp)` 是一個普通函式,型別說「任何有 `hp` 欄位的 `r` 都能用」——
這就是第 2 章 `shoutName = T.toUpper . (.name)` 能合成的原因。

## 常見誤區

1. `data` 的欄位型別寫錯位置:`Dragon Element Int` 是建構子帶兩個欄位,不是型別參數。
2. 在 sum type 的分支上用 record 欄位 → 不完整更新/存取警告。
3. 一個建構子一個欄位寫成 `data` 而不是 `newtype`,白白多一層 box。
4. 想用 `hp p` 讀欄位 → `Variable not in scope`,改用 `p.hp`。
5. 建構子和型別同名(`data Player = Player {...}`)是慣例,不是必須;兩者活在不同命名空間。

## 2026 實務準則

1. 領域建模先寫 ADT,再寫函式;算一下型別能表達的狀態數是否等於合法狀態數。
2. record 一律 `OverloadedRecordDot` + `NoFieldSelectors`,讀用 `.`,寫用 `{ }`。
3. 單欄位包裝一律 `newtype`。
4. `deriving` 永遠標策略(第 5 章)。

## 習題

`exercises/Exercises/E04Adts.hs` → `cabal test level01-foundations`
