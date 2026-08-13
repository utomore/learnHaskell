# 第 1 章 — Phantom types 與 DataKinds

## 問題:同型別、不同意義

```haskell
attack :: Int -> Int -> IO ()   -- 哪個是 heroId、哪個是 monsterId?
attack monsterId heroId          -- 傳反了,編譯器沒意見,上線才爆
```

`Int` 太寬:它能表達任何整數,但我們想表達的是「英雄的 ID」。

## Phantom type:只存在於型別的標籤

```haskell
newtype Id entity = Id Int      -- entity 沒出現在等號右邊 → 幽靈參數
  deriving stock (Eq, Ord, Show)

data Hero      -- 空型別:沒有值,只當標籤用
data Monster

attack :: Id Monster -> Id Hero -> IO ()
```

現在 `attack heroId monsterId` **無法編譯**。
執行期什麼都沒多:`Id Hero` 和 `Id Monster` 底層都是一個 `Int`,
零成本 —— 所有檢查都發生在編譯期。

## DataKinds:讓標籤自成一族

空型別標籤有個弱點:`Id Bool`、`Id String` 也合法,標籤沒有「族」的概念。
`DataKinds`(GHC2024 內建)把資料型別**升級成 kind**:

```haskell
data TempUnit = Celsius | Fahrenheit          -- 一般的 ADT

newtype Temp (u :: TempUnit) = Temp Double    -- u 只能是 'Celsius 或 'Fahrenheit
  deriving stock (Eq, Show)

toFahrenheit :: Temp 'Celsius -> Temp 'Fahrenheit
```

`'Celsius`(帶撇號)是**型別層級**的 `Celsius`。
現在攝氏華氏不可能混用,而 `Temp Bool` 這種無意義組合直接是 kind error。

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

## 2026 實務準則

1. ID、單位、金額這類「底層同型別、語義不同」的值,一律 newtype + phantom tag。
2. 需要限制標籤範圍時用 DataKinds,不要裸的空型別。
3. 驗證函式回傳「換了標籤的型別」,讓下游 API 只收驗證過的值。

## 習題

`exercises/Exercises/E01Phantom.hs` —— 三題:
tagged ID(`nextId`)、單位換算(`toFahrenheit`)、
parse-don't-validate(`validateName` / `greet`)。
