# 第 1 章 — Phantom types 與 DataKinds

## 問題:同型別、不同意義

```haskell
attack :: Int -> Int -> IO ()   -- 哪個是 heroId、哪個是 monsterId?
attack monsterId heroId          -- 傳反了,編譯器沒意見,上線才爆
```

`Int` 太寬:它能表達任何整數,但我們想表達的是「英雄的 ID」。
這類 bug 有個名字:**primitive obsession**(原始型別成癮)——
所有東西都是 `Int`、`Text`、`Double`,型別檢查器等於沒上班。

## Phantom type:只存在於型別的標籤

```haskell
newtype Id entity = Id Int      -- entity 沒出現在等號右邊 → 幽靈參數
  deriving stock (Eq, Ord, Show)

data Hero      -- 空型別:沒有值,只當標籤用
data Monster

attack :: Id Monster -> Id Hero -> IO ()
```

現在 `attack heroId monsterId` **無法編譯**:

```
P1Mix.hs:12:15: error: [GHC-83865]
    • Couldn't match type ‘Hero’ with ‘Monster’
      Expected: Id Monster
        Actual: Id Hero
    • In the first argument of ‘attack’, namely ‘heroId’
```

執行期什麼都沒多:`Id Hero` 和 `Id Monster` 底層都是一個 `Int`,
零成本 —— 所有檢查都發生在編譯期。

### 來龍去脈:從「空型別當標籤」到 DataKinds

phantom type 是 1990 年代末就有的技巧(Leijen 與 Meijer 1999 年用它做
型別安全的 SQL DSL)。當年的做法就是上面那樣:宣告幾個**沒有建構子的
空型別**當標籤。它能用,但有兩個毛病:

1. **標籤沒有「族」的概念**:`Id Hero`、`Id Monster` 合法,`Id Bool`、
   `Id [Text]` 也合法。任何 kind 為 `Type` 的東西都能塞進去,
   標籤只是「碰巧不同」而不是「被宣告為一組」。
2. **列舉不完**:想寫「對所有合法標籤做某件事」,型別系統不知道
   合法標籤有哪些。

2012 年的論文 *Giving Haskell a Promotion* 帶來了 `DataKinds`(GHC 7.4):
一般的 `data` 宣告會**同時**產生一個 kind 和一組型別層級的建構子。
從此標籤可以是一個封閉的集合。舊教材與舊函式庫(2012 前的 `tagged`、
早期 `servant`)裡看到空型別當標籤,就是這段歷史;
新程式碼要用下一節的寫法。

## DataKinds:讓標籤自成一族

`DataKinds`(GHC2024 內建)把資料型別**升級成 kind**:

```haskell
data TempUnit = Celsius | Fahrenheit          -- 一般的 ADT

newtype Temp (u :: TempUnit) = Temp Double    -- u 只能是 'Celsius 或 'Fahrenheit
  deriving stock (Eq, Show)

toFahrenheit :: Temp 'Celsius -> Temp 'Fahrenheit
```

`'Celsius`(帶撇號)是**型別層級**的 `Celsius`。撇號用來消歧義:
`Celsius` 既是值層的建構子,也是型別層的型別;沒有歧義時撇號可以省略,
GHC 會自己找,但習慣上遇到「和某個型別同名」的建構子(例如 `'[]`、`'True`)
一定要加。

現在攝氏華氏不可能混用,而 `Temp Bool` 這種無意義組合直接是 kind error。

### `type data`:只要型別、不要值(GHC 9.6+)

用 `data TempUnit = Celsius | Fahrenheit` 當標籤有個小尷尬:
它同時產生了**值層**的 `Celsius :: TempUnit`,但我們永遠不會拿它當值用。
`TypeData` 擴充(GHC 9.6,不在 GHC2024 內)宣告「純型別層」的資料:

```haskell
{-# LANGUAGE TypeData #-}

type data TempUnit = Celsius | Fahrenheit   -- 只活在型別層,沒有值

newtype Temp (u :: TempUnit) = Temp Double
toFahrenheit :: Temp Celsius -> Temp Fahrenheit   -- 連撇號都不需要
```

拿 `Celsius` 當值會被擋下來,訊息很直白:

```
error: [GHC-01928]
    • Illegal term-level use of the type constructor ‘Celsius’
```

**2026 的取捨**:標籤純粹是標籤 → `type data`;
標籤同時也是執行期會用到的資料(例如要 `show` 它、從設定檔解析它)→
一般 `data` + DataKinds。本章習題用後者,因為測試會拿 `TempUnit` 的值。

## 讓標籤「開口說話」:Proxy 與 TypeApplications

標籤只在型別裡,執行期沒有值。想根據標籤印出單位符號怎麼辦?
標準手法是**用 typeclass 在型別上做 dispatch**,再用 `Proxy` 把型別帶進來:

```haskell
import Data.Proxy (Proxy (..))

class KnownUnit (u :: TempUnit) where
  unitName :: Proxy u -> Text
instance KnownUnit Celsius    where unitName _ = "°C"
instance KnownUnit Fahrenheit where unitName _ = "°F"

render :: forall u. KnownUnit u => Temp u -> Text
render (Temp d) = tshow d <> unitName (Proxy @u)
```

- `Proxy u` 是一個沒有內容的值,唯一用途是把型別 `u` 傳給函式。
- `forall u.` 明寫出來之後,函式本體才能用 `@u` 指名這個型別變數
  (這叫 `ScopedTypeVariables`,GHC2024 內建)。
- `Proxy @u` 是 `TypeApplications`:直接把型別當引數傳。

GHC 9.10 起的 `RequiredTypeArguments` 讓「型別當引數」不再需要 `Proxy`,
第 8 章會補。現在先認得 `Proxy`,它在 2026 的函式庫裡仍到處都是。

## Parse, don't validate

phantom 最重要的實戰模式:用型別記住「這筆資料驗證過了沒」。

```haskell
data Raw          -- 尚未驗證
data Validated    -- 驗證通過

newtype PlayerName s = PlayerName Text

validateName :: PlayerName Raw -> Either Text (PlayerName Validated)
greet        :: PlayerName Validated -> Text   -- 只收驗證過的!
```

`greet` 的型別就是文件:不可能拿沒驗證的輸入呼叫它。
驗證只需做一次,之後整條管線都由編譯器擔保 ——
這就是「parse, don't validate」:把檢查結果**存進型別**,
而不是到處重複 if。

### 封裝:不匯出建構子,標籤才有意義

上面的模式有個漏洞:如果別的模組能寫 `PlayerName "" :: PlayerName Validated`,
標籤就是假的。所以**模組匯出清單要藏住建構子**:

```haskell
module Player
  ( PlayerName          -- 只匯出型別,不匯出 PlayerName 建構子
  , Raw, Validated
  , mkRawName           -- Text -> PlayerName Raw:唯一的入口
  , validateName
  , greet
  ) where
```

外面的人只能透過 `mkRawName` 拿到 `Raw`、透過 `validateName` 拿到 `Validated`。
這叫 **smart constructor** 模式;phantom tag + 藏建構子 = 型別層的狀態機。
(本章習題為了讓測試能直接建值,匯出了 `PlayerName (..)`;
實務專案請關起來。)

## 你會看到的錯誤訊息

把 `Bool` 塞進 kind 為 `TempUnit` 的位置:

```
P1KindErr.hs:4:13: error: [GHC-83865]
    • Expected kind ‘TempUnit’, but ‘Bool’ has kind ‘*’
    • In the first argument of ‘Temp’, namely ‘Bool’
      In the type signature: bad :: Temp Bool
```

怎麼讀:
- `Expected kind ‘TempUnit’`:`Temp` 的參數 `u` 被宣告成 `u :: TempUnit`。
- `‘Bool’ has kind ‘*’`:`*` 是 `Type` 的舊寫法(9.14 的訊息裡仍會出現),
  意思是「Bool 是普通型別,不是 TempUnit 家族的成員」。
- 修法:換成 `'Celsius` / `'Fahrenheit`;或者如果你真的想放任意型別,
  把宣告改回 `newtype Temp u = ...`(不標 kind,即回到裸 phantom)。

「kind」就是型別的型別。`Int :: Type`、`Maybe :: Type -> Type`、
`'Celsius :: TempUnit`。看到 kind error,先問自己:這個位置要的是哪一族?

## ghci 實驗

```haskell
cabal repl level03-advanced
ghci> import Exercises.E01Phantom
ghci> :kind Temp
Temp :: TempUnit -> *
ghci> :kind! Temp 'Celsius
Temp 'Celsius :: *
= Temp Celsius                   -- 沒有歧義時 GHC 印出來會省略撇號
ghci> :kind 'Celsius
'Celsius :: TempUnit
ghci> :t Temp 3
Temp 3 :: Temp u                 -- 標籤未定:由使用處決定
ghci> :t toFahrenheit
toFahrenheit :: Temp 'Celsius -> Temp 'Fahrenheit
```

`:kind` 看 kind;`:kind!` 順便把 type family 算完(第 3 章會用到)。

## 常見誤區

1. **以為 phantom 有執行期成本**:沒有,`newtype` 在編譯後消失,
   `Id Hero` 就是一個 `Int`。
2. **匯出了建構子**:別的模組能自己捏 `Validated`,標籤形同虛設。
3. **用 `String`/`Bool` 當標籤**:能編過,但沒有「族」的約束;
   要 DataKinds 或 `type data`。
4. **標籤太多層**:`Id (Validated (Owned Hero))` 這種型別開始難讀時,
   停下來想想是不是該用 record 或 GADT(下一章)。

## 2026 實務準則

1. ID、單位、金額這類「底層同型別、語義不同」的值,一律 newtype + phantom tag。
2. 需要限制標籤範圍時用 DataKinds(或 `type data`),不要裸的空型別。
3. 驗證函式回傳「換了標籤的型別」,讓下游 API 只收驗證過的值,
   並且**不匯出建構子**。
4. 需要在執行期「問標籤是誰」→ typeclass + `Proxy`/`TypeApplications`。

## 習題

`exercises/Exercises/E01Phantom.hs` —— 三題:
tagged ID(`nextId`)、單位換算(`toFahrenheit`)、
parse-don't-validate(`validateName` / `greet`)。
