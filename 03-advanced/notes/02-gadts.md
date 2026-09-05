# 第 2 章 — GADTs:讓建構子攜帶型別證據

## 問題:普通 ADT 表達不了「這個節點是什麼型別」

寫一個小 DSL(例如遊戲的傷害公式、觸發條件):

```haskell
data Expr = IntE Int | BoolE Bool | Add Expr Expr | If Expr Expr Expr

eval :: Expr -> ???   -- 回傳 Int 還是 Bool?只能回 Either,到處 runtime check
Add (IntE 1) (BoolE True)   -- 型別錯的程式,照樣建得出來
```

### 來龍去脈:GADT 之前大家怎麼活

Haskell 98 的 ADT 有個隱含規則:**每個建構子的回傳型別都一樣**,
就是 `data` 那一行宣告的型別本身(`Expr`)。所以「`IntE` 回 `Expr Int`、
`BoolE` 回 `Expr Bool`」在語法上根本寫不出來。

2000 年代初的解法有三種,你在舊程式碼還會看到:

1. **動態檢查**:`eval :: Expr -> Either Text Value`,`Value` 是
   `VInt Int | VBool Bool`,每個節點求值後再 case 一次。型別安全歸零,
   DSL 使用者寫錯要跑起來才知道。
2. **Phantom + smart constructor**(上一章的技巧):`newtype Expr a = Expr RawExpr`,
   只匯出 `intE :: Int -> Expr Int`、`add :: Expr Int -> Expr Int -> Expr Int`。
   建構端安全了,但 **pattern match 時 phantom 不會告訴你任何事**,
   `eval` 還是得回 `Value`。
3. **Church encoding / finally tagless**:用 typeclass 取代資料型別。
   有效但門檻高,而且沒有一棵可以檢查、序列化的樹。

GADT 在 2003–2005 年間進入 GHC(6.4 正式支援),核心貢獻只有一件事:
**讓 pattern match 可以精煉型別**。前兩種做法的缺口就此補上。

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
不合法的程式在 DSL 裡根本寫不出來:

```
P2Bad.hs:6:21: error: [GHC-83865]
    • Couldn't match type ‘Bool’ with ‘Int’
      Expected: Expr Int
        Actual: Expr Bool
    • In the second argument of ‘Add’, namely ‘(BoolE True)’
```

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

### 精煉也會反過來幫你少寫分支

只處理 `Expr Int` 的函式,GHC 知道 `BoolE`、`Leq` **不可能**出現,
`-Wincomplete-patterns` 不會抱怨:

```haskell
evalInt :: Expr Int -> Int
evalInt (IntE n)   = n
evalInt (Add x y)  = evalInt x + evalInt y
evalInt (If c t e) = if eval c then evalInt t else evalInt e
-- 沒寫 BoolE / Leq:-Wall 下零警告
```

反過來,如果你硬寫 `evalInt (BoolE b) = ...`,`-Wall` 會給兩個警告:
`-Winaccessible-code`(「Inaccessible code ... Couldn't match type ‘Int’
with ‘Bool’」:這個分支在型別上不可達)和 `-Woverlapping-patterns`
(這條等式永遠比不到)。

## 你會看到的錯誤訊息:忘了寫簽名

GADT 的精煉**必須知道你想精煉什麼**。沒有簽名,GHC 只能推出
`eval :: Expr a -> p`,然後在分支裡發現 `p` 必須同時是 `Int` 和 `Bool`:

```
P2NoSig.hs:5:18: error: [GHC-25897]
    • Could not deduce ‘p ~ Int’
      from the context: a ~ Int
        bound by a pattern with constructor: IntE :: Int -> Expr Int,
                 in an equation for ‘eval’
      ‘p’ is a rigid type variable bound by
        the inferred type of eval :: Expr a -> p
    • In the expression: n
    Suggested fix: Consider giving ‘eval’ a type signature
```

怎麼讀:
- `from the context: a ~ Int`:match 到 `IntE`,GHC 確實拿到了 `a ~ Int` 這條證據。
- `Could not deduce ‘p ~ Int’`:但回傳型別是它自己推的 `p`,和 `a` 沒關係,
  證據用不上。
- `rigid type variable`:「僵硬」的型別變數 = 不能被 unify 成別的東西。
- `Suggested fix`:GHC 自己說了 —— **寫簽名**。這條錯誤幾乎永遠是這個原因。

規則:**用到 GADT 精煉的函式一律寫簽名**。這也是 GHC2024 內建
`MonoLocalBinds` 的原因之一:局部定義不做泛化,避免這類推導失敗。

## 真正的痛點:從外部資料解析成 GADT

DSL 總得從文字/JSON 讀進來。問題來了:

```haskell
parse :: Text -> Maybe (Expr ???)   -- 讀到 "42" 是 Expr Int,讀到 "true" 是 Expr Bool
```

`???` 填不出來 —— 型別要在**編譯期**決定,但輸入是**執行期**才知道的。
這不是 GADT 的缺陷,是所有靜態型別語言的本質:執行期資料的型別要用
執行期的值來表達。

### 解法一:存在型別包裝(把 `a` 藏起來)

```haskell
data SomeExpr where
  SomeExpr :: Expr a -> SomeExpr      -- a 不出現在結果型別:存在型別

parseLit :: Text -> Maybe SomeExpr
parseLit "true"  = Just (SomeExpr (BoolE True))
parseLit "false" = Just (SomeExpr (BoolE False))
parseLit t       = SomeExpr . IntE <$> readMaybe (T.unpack t)
```

`SomeExpr` 說的是「裡面有**某個** `a` 的 `Expr a`,但我不告訴你是哪個」。
拆開之後你能做的只有**對任何 `a` 都成立的事**:

```haskell
describe :: SomeExpr -> Text
describe (SomeExpr e) = "節點數 " <> tshow (size e)   -- size :: Expr a -> Int,OK
```

想 `eval` 它就不行了,因為 `a` 逃不出去:

```
P2Escape.hs:10:23: error: [GHC-25897]
    • Couldn't match expected type ‘p’ with actual type ‘a’
      ‘a’ is a rigid type variable bound by
        a pattern with constructor:
          SomeExpr :: forall a. Expr a -> SomeExpr
```

### 解法二:帶著型別證據一起包

要恢復 `a`,就讓包裝裡**多放一個描述 `a` 的值**(singleton):

```haskell
data Ty a where            -- 「a 是什麼」的執行期證據
  TInt  :: Ty Int
  TBool :: Ty Bool

data TypedExpr where
  TypedExpr :: Ty a -> Expr a -> TypedExpr

parseAdd :: Text -> Text -> Maybe TypedExpr
parseAdd a b = do
  TypedExpr ta ea <- parseTyped a
  TypedExpr tb eb <- parseTyped b
  case (ta, tb) of
    (TInt, TInt) -> Just (TypedExpr TInt (Add ea eb))   -- match 到 TInt → a ~ Int
    _            -> Nothing                             -- 型別不合:解析失敗
```

match `TInt` 的瞬間 GHC 得到 `a ~ Int`,於是 `Add ea eb` 合法。
這就是**型別檢查器搬到執行期**的樣子:解析器本身變成一個小小的 type checker。
標準函式庫版本是 `Data.Typeable` 的 `TypeRep`/`eqTypeRep`;
概念完全一樣,只是證據是泛用的。

## Deriving:GADT 要用 standalone deriving

`deriving stock` 寫在 GADT 宣告尾巴會被拒絕:

```
P2Deriv.hs:5:18: error: [GHC-16437]
    • Can't make a derived instance of
        ‘Show (Expr a)’ with the stock strategy:
        Constructor ‘IntE’ is a GADT
    Suggested fix: Use a standalone deriving declaration instead
```

原因:普通 deriving 假設所有建構子回同一個型別,GADT 不是。
改用 standalone deriving(GHC2024 內建),寫在型別宣告外面:

```haskell
deriving instance Show (Expr a)
deriving instance Eq (Expr a)
```

## 什麼時候用

- **DSL / AST**:解譯器、規則引擎、查詢語言 —— GADT 的主場。
- **帶不變量的資料**:長度索引向量、狀態機(狀態編碼在型別)。
- 反例:資料就是普通資料時,別硬上 GADT,普通 ADT 的
  deriving、泛型都比較順。

小提醒:GADT 的 `deriving stock` 支援有限,`Show`/`Eq` 常需要
standalone deriving(`deriving instance Show (Expr a)`)或手寫。
測試裡常見的替代:比較 `eval` 結果或 `render` 輸出。

## ghci 實驗

```haskell
cabal repl level03-advanced
ghci> import Exercises.E02Gadts
ghci> :t IntE 1
IntE 1 :: Expr Int
ghci> :t If
If :: Expr Bool -> Expr a -> Expr a -> Expr a
ghci> eval (If (Leq (IntE 1) (IntE 2)) (IntE 10) (IntE 20))
10
ghci> :i Expr                 -- 注意第一行:type role Expr nominal
```

`type role Expr nominal` 的意思:`Expr Int` 和 `Expr Age`(即使 `Age` 是
`Int` 的 newtype)**不能** `coerce` 互轉,因為型別索引是證據,不只是標籤。
第 4 章講 role 時會再回來看這行。

## 常見誤區

1. **沒寫簽名**就用精煉 → rigid type variable 錯誤,先補簽名。
2. 想 `parse :: Text -> Expr a` → 不可能,要 `SomeExpr` 或帶證據的包裝。
3. 拆開 `SomeExpr` 之後想 `eval` → `a` 逃不出去,要證據(`Ty a`/`Typeable`)。
4. 在 GADT 上寫 `deriving stock` → 改 standalone deriving。
5. 把普通 record 寫成 GADT 語法只為了「看起來高級」→ 失去 deriving 便利,
   沒有任何好處。

## 2026 實務準則

1. DSL 一律 GADT:把「型別對不對」從解譯器搬到建構期。
2. `eval :: Expr a -> a` 這種索引消除函式是標配,寫 DSL 先寫它。
3. 不變量進型別的成本是易用性,先從最痛的一兩個不變量開始。
4. 邊界(解析、反序列化)一定要有存在型別包裝 + 型別證據,
   這是 GADT 專案裡「最像 type checker」的一段程式碼,值得好好寫。

## 習題

`exercises/Exercises/E02Gadts.hs` —— 傷害公式 DSL:
`eval`(解譯)、`render`(輸出可讀公式)、`size`(節點數)。
