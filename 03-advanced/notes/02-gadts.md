# 第 2 章 — GADTs:讓建構子攜帶型別證據

## 問題:普通 ADT 表達不了「這個節點是什麼型別」

寫一個小 DSL(例如遊戲的傷害公式、觸發條件):

```haskell
data Expr = IntE Int | BoolE Bool | Add Expr Expr | If Expr Expr Expr

eval :: Expr -> ???   -- 回傳 Int 還是 Bool?只能回 Either,到處 runtime check
Add (IntE 1) (BoolE True)   -- 型別錯的程式,照樣建得出來
```

## GADT 語法:每個建構子自己宣告完整型別

GADTs 在 GHC2024 內建。把型別參數 `a` 當作「這個運算式算出什麼」:

```haskell
data Expr a where
  IntE  :: Int  -> Expr Int
  BoolE :: Bool -> Expr Bool
  Add   :: Expr Int  -> Expr Int -> Expr Int
  Leq   :: Expr Int  -> Expr Int -> Expr Bool
  If    :: Expr Bool -> Expr a   -> Expr a -> Expr a
```

現在 `Add (IntE 1) (BoolE True)` **無法編譯** ——
不合法的程式在 DSL 裡根本寫不出來。

## Pattern match 會精煉型別

```haskell
eval :: Expr a -> a
eval (IntE n)  = n            -- 這個分支裡,GHC 知道 a ~ Int
eval (BoolE b) = b            -- 這裡 a ~ Bool
eval (Add x y) = eval x + eval y
eval (If c t e) = if eval c then eval t else eval e
```

這是 GADT 的核心能力:**match 到哪個建構子,就免費得到哪個型別等式**。
`eval` 不需要 `Either`、不需要 runtime check,total 又型別安全。

一個值得注意的細節:`eval :: Expr a -> a` 對「所有 a」都要成立,
但每個分支只處理特定的 a —— 建構子攜帶的型別證據補上了缺口。

## 什麼時候用

- **DSL / AST**:解譯器、規則引擎、查詢語言 —— GADT 的主場。
- **帶不變量的資料**:長度索引向量、狀態機(狀態編碼在型別)。
- 反例:資料就是普通資料時,別硬上 GADT,普通 ADT 的
  deriving、泛型都比較順。

小提醒:GADT 的 `deriving stock` 支援有限,`Show`/`Eq` 常需要
standalone deriving(`deriving instance Show (Expr a)`)或手寫。
測試裡常見的替代:比較 `eval` 結果或 `render` 輸出。

## 2026 實務準則

1. DSL 一律 GADT:把「型別對不對」從解譯器搬到建構期。
2. `eval :: Expr a -> a` 這種索引消除函式是標配,寫 DSL 先寫它。
3. 不變量進型別的成本是易用性,先從最痛的一兩個不變量開始。

## 習題

`exercises/Exercises/E02Gadts.hs` —— 傷害公式 DSL:
`eval`(解譯)、`render`(輸出可讀公式)、`size`(節點數)。
