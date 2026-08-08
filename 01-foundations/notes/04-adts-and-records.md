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

處理 ADT 就是 pattern matching,編譯器會檢查你**沒漏掉任何案例** ——
新增一種怪物,所有忘記處理它的地方都會變成編譯警告。這是
「**把非法狀態變成無法表達**」(make illegal states unrepresentable)哲學的基礎。

```haskell
describeMonster :: Monster -> Text
describeMonster = \case          -- \case:直接對唯一引數做 case
  Slime hp -> ...
  Dragon el hp -> ...
```

## Record:2026 的寫法

```haskell
{-# LANGUAGE NoFieldSelectors #-}   -- 模組頂端

data Player = Player
  { name :: Text
  , hp :: Int
  , maxHp :: Int
  }
  deriving stock (Eq, Show)
```

搭配已全域開啟的 `OverloadedRecordDot`,存取欄位用**點語法**:

```haskell
ghci> sampleHero.hp
100
ghci> sampleHero.name
"Hero"
```

- **`NoFieldSelectors`**:關掉舊式的頂層 selector 函式(舊行為會讓 `name`、`hp`
  變成全域函式,不同型別欄位名互撞,是歷史痛點)。現代 Haskell 用點語法。
- 建構與更新照舊:

```haskell
hero = Player {name = "Hero", hp = 100, maxHp = 100}

takeDamage :: Int -> Player -> Player
takeDamage dmg p = p {hp = max 0 (p.hp - dmg)}   -- 產生新值,不是就地修改
```

這個 `World -> World` 的更新模式,就是之後 game loop 每一幀在做的事。

## newtype:零成本的型別包裝

```haskell
newtype Gold = Gold Int
```

執行期和 `Int` 完全相同(零開銷),但型別系統會阻止你把金幣加到 HP 上。
單位、ID、金額……都該包 newtype。第 5 章會配 deriving 一起用。

## Maybe 與 Either 也只是 ADT

```haskell
data Maybe a    = Nothing | Just a
data Either e a = Left e  | Right a   -- 慣例:Left 放錯誤,Right 放成功
```

沒有魔法 —— 你在第 2 章用的 `Maybe` 自己就能定義。
`Either` 讓失敗帶原因,是之後錯誤處理章節的基石。

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

## 習題

`exercises/Exercises/E04Adts.hs` → `cabal test level01-foundations`
