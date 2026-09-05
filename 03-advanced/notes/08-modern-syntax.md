# 第 8 章 — GHC 9.10 到 9.14 的新語法

> 本課程以 GHC 9.14 為基準。2024 到 2026 年之間語言本身變了不少:
> 預設語言換成 GHC2024、`head` 開始被警告、`foldl'` 進了 Prelude、
> 例外有了 backtrace,還多了好幾個新語法。這章把它們集中講一次:
> 每個都回答「以前怎麼寫、為什麼要改、現在該不該用」。
> 很多項目前面章節已經用過,這裡只補來龍去脈並指回去。

## GHC2024:預設語言換了

GHC 9.10 起,`default-language: GHC2024` 可用,它在 GHC2021 之上再打開八個擴充:

| 擴充 | 這門課在哪裡用到 | 以前為什麼要手動開 |
|------|------|------|
| `LambdaCase` | Level 1 第 4、8 章的 `\case` | 2012 年才有,GHC2021 定案時被認為「太新」 |
| `DerivingStrategies` | 每一個 `deriving stock` | 沒有它,`deriving` 在 newtype 上有歧義(Level 3 第 4 章) |
| `GADTs` | Level 3 第 2 章 | 曾被視為進階功能 |
| `DataKinds` | Level 3 第 1 章 | 同上 |
| `RoleAnnotations` | 第 4 章的 `coerce` 相關 | 少用,但 `DerivingVia` 生態需要 |
| `MonoLocalBinds` | (隱含) | `GADTs`/`TypeFamilies` 需要它讓推斷可判定 |
| `DisambiguateRecordFields` | record 欄位同名 | 現代 record 的一部分 |
| `ExplicitNamespaces` | `import M (type T)` | 型別與資料建構子同名時區分 |

在 ghci 裡 `:show language` 可以看目前的基準。**沒有**進 GHC2024、
所以本專案寫在 cabal `default-extensions` 裡的:`OverloadedStrings`、
`OverloadedRecordDot`、`NoFieldSelectors`。需要時再逐檔開的:
`TypeFamilies`、`DerivingVia`、`OrPatterns`、`MultilineStrings`、
`RequiredTypeArguments`。

**來龍去脈**:Haskell 2010 是最後一個正式語言標準,之後十幾年新功能全部
以「擴充」存在,每個檔案開頭一長串 `{-# LANGUAGE ... #-}` 成了 Haskell 的
招牌畫面。GHC2021(GHC 9.2,2021 年)第一次把「大家都會開的」收成一個
基準;GHC2024 是三年後的第二版。慣例是每幾年出一版,舊的不會消失,
所以舊專案寫 `GHC2021` 或什麼都不寫(= `Haskell2010`)都還會看到。

## 前面章節已經用過的:回頭看

| 版本 | 變化 | 你在哪裡遇過 |
|------|------|------|
| 9.4 | `\cases`:一次比對多個引數 | 本章下面 |
| 9.6 | `TypeData`:`type data` 宣告只存在於型別層的標籤 | Level 3 第 1 章 |
| 9.8 | `-Wx-partial`:`head`/`tail` 開始被警告 | Level 1 第 2、8 章 |
| 9.10 | `foldl'` 進 Prelude、`GHC2024`、例外 backtrace | Level 1 第 3 章、Level 2 第 6 章 |
| 9.10 | `RequiredTypeArguments` | 本章下面 |
| 9.12 | `OrPatterns`、`MultilineStrings`、`NamedDefaults` | 本章下面 |
| 9.14 | `ExplicitLevelImports`(Template Haskell 用) | 只識讀 |

## `\cases`(GHC 9.4):多引數的 `\case`

```haskell
-- 屬性相剋表
multiplier :: Element -> Element -> Double
multiplier = \cases
  Fire Grass -> 2
  Grass Ice -> 2
  Ice Fire -> 2
  Grass Fire -> 0.5
  Ice Grass -> 0.5
  Fire Ice -> 0.5
  _ _ -> 1
```

- **舊做法**:`multiplier a b = case (a, b) of (Fire, Grass) -> 2; ...`,
  為了 case 兩個引數先包一個 tuple 再拆開。這個 tuple 純粹是語法需要,
  最佳化器會消掉它,但讀起來多一層。
- **新做法**:`\cases` 每個分支直接列出所有引數的 pattern,也能加 guard。
- **在 GHC2024 內**(隨 `LambdaCase` 一起),直接用。

## `RequiredTypeArguments`(GHC 9.10):`forall a ->`

### 問題:「給我一個型別」的 API

```haskell
sizeOf :: Storable a => a -> Int        -- 傳 undefined 進去只為了指定型別?
typeRep :: Typeable a => Proxy a -> TypeRep   -- 傳一個 Proxy 當型別載體
```

Level 1 第 8 章的 `@T` 已經解決大半:`maxBound @Int`。但 `@T` 是**可選**的
——編譯器推得出來時你可以不寫。有些 API 的型別引數根本推不出來,
只能靠呼叫端給,函式庫作者想讓它變成**必填**。

### 新做法:visible forall

```haskell
boundsOf :: forall a -> (Bounded a, Show a) => Text
boundsOf a = T.pack (show (minBound :: a)) <> " .. " <> T.pack (show (maxBound :: a))
```

```haskell
ghci> boundsOf Bool
"False .. True"
ghci> boundsOf Element
"Fire .. Grass"
```

`forall a ->`(箭頭,不是句點)表示「`a` 是一個要**寫在引數位置**的型別」。
定義裡 `boundsOf a = ...` 的 `a` 就是那個型別,可以直接拿來寫 `:: a`。
呼叫時 `boundsOf Bool`,型別直接出現在 term 的位置。

### 來龍去脈

- **舊做法**:`Proxy`(2012 年前後成為慣例)、`undefined :: T`(更老、更醜)、
  `@T`(2016 年,但只是可選)。
- **為什麼會這樣**:Haskell 一直嚴格區分「term 的世界」和「型別的世界」,
  型別引數是隱式的。Dependent Haskell 路線圖(2016 年起)想逐步打通,
  visible forall 是第一個真正落地的 term 層語法。
- **該不該用**:寫函式庫 API、型別引數本來就是「主要輸入」時用。
  日常應用碼裡 `@T` 夠了。**讀**到 `forall a ->` 要認得它。
- **注意**:習題骨架不能寫 `boundsOf = undefined`,會看到
  `Cannot instantiate unification variable ‘a0’ with a type involving polytypes`——
  visible forall 的函式必須把那個型別引數綁起來,所以骨架寫成 `boundsOf _ = undefined`。

## `OrPatterns`(GHC 9.12):一個分支比對多個 pattern

```haskell
isMeta :: Cmd -> Bool
isMeta (Help; Version; Quit) = True
isMeta _ = False

parseCmd :: Text -> Maybe Cmd
parseCmd t = case T.words (T.toLower t) of
  ["go", dir] -> Just (Go dir)
  (["look"]; ["l"]) -> Just Look
  (["quit"]; ["q"]; ["exit"]) -> Just Quit
  _ -> Nothing
```

分號分隔的幾個 pattern,任一個符合就走這個分支。**外面一定要括號**,
不然是 `parse error on input ‘;’`(這個錯誤訊息的意思不是「不能用分號」,
是 parser 把它當成 layout 的分號了)。

- **舊做法**:同一個右手邊抄 N 次;或者 ``x `elem` [Help, Version, Quit]``
  (需要 `Eq`,而且比對不會被 `-Wincomplete-patterns` 追蹤);
  或者 view pattern。
- **為什麼拖了這麼久**:2020 年提案,爭論點是 or-pattern 裡能不能綁變數
  (`(Just x; Right x)`)。最後 9.12 落地的版本**不能綁變數**,只能列常數
  與不帶變數的建構子。這個限制讓語意簡單、pattern 完整性檢查能正確運作。
- **該不該用**:多個建構子共用同一個結果時用,可讀性明顯提升。
  需要綁變數就回到多條等式。

## `MultilineStrings`(GHC 9.12):`"""` 字串

```haskell
helpText :: Text
helpText =
  """
  指令:
    go <方向>  移動
    look       觀察四周
  """
```

規則(實測 GHC 9.14.1):開頭 `"""` 後的換行被拿掉、
結尾 `"""` 前的換行被拿掉、所有行的**共同縮排**被拿掉。
上面的 `helpText` 是 3 行,第一行是 `指令:`,第二行以兩個空白開頭。
`OverloadedStrings` 照常生效,所以它可以直接是 `Text`。

- **舊做法**:`unlines ["指令:", "  go <方向>  移動", ...]`,或者 Haskell 98 的
  string gap 語法 `"第一行\n\` `\第二行"`(反斜線、換行、反斜線),
  後者幾乎沒有人看得懂。
- **該不該用**:說明文字、SQL、內嵌模板,直接用。

## `NamedDefaults`(GHC 9.12):自訂預設型別

Haskell 98 的 `default (Integer, Double)` 只能管標準數字 class。
`NamedDefaults` 讓你為任何 class 指定「歧義時預設用什麼」:

```haskell
{-# LANGUAGE NamedDefaults #-}
default Num (Double)     -- 這個模組裡的數字字面值歧義時預設 Double

ghci> print (2 * 3)
6.0
```

- **為什麼會有它**:`OverloadedStrings` 讓字串字面值多載後,ghci 裡
  `"abc"` 到底是 `String` 還是 `Text` 常常歧義;函式庫作者也想讓
  自家 class 的字面值有合理預設。
- **該不該用**:應用碼幾乎用不到。知道它存在,看到 `default Foo (Bar)`
  不要嚇到。

## `ExplicitLevelImports`(GHC 9.14):只識讀

Template Haskell 的 splice 在**編譯期**執行,它用到的模組和執行期
用到的模組其實是兩件事。9.14 讓你用 `import splice M` / `import quote M`
標明一個 import 只用在哪個階段,編譯器就能少編、少連結。
本課程不教 Template Haskell;讀到這種 import 知道是什麼即可。

## 你會看到的錯誤訊息

or-pattern 沒加括號:

```
error: [GHC-58481] parse error on input ‘;’
   |
29 |   ["quit"; "exit"] -> Just Quit
   |          ^
```

修法:`(["quit"]; ["exit"])`。注意每個選項都要是完整的 pattern
(這裡是 list pattern),不是 `["quit"; "exit"]` 這種「list 裡面二選一」。

在 GHC2021 專案裡寫 `\case`:

```
error: [GHC-51179]
    Illegal \case
    Suggested fix:
      Perhaps you intended to use the ‘LambdaCase’ extension
```

修法:換 `default-language: GHC2024`,或單檔開 `LambdaCase`。

## ghci 實驗

```haskell
cabal repl level03-advanced
ghci> :show language
base language is: GHC2024
ghci> :set -XOrPatterns -XMultilineStrings
ghci> let f (1; 2; 3) = "小"; f _ = "大"
ghci> map f [1, 2, 5 :: Int]
["小","小","大"]
ghci> import Exercises.E10ModernSyntax
ghci> boundsOf Element
"Fire .. Grass"
```

## 常見誤區

1. 新語法要先確認**擴充有沒有開**:`OrPatterns`、`MultilineStrings`、
   `RequiredTypeArguments` 都不在 GHC2024,要在檔案頂端或 cabal 開。
2. or-pattern 想綁變數 → 不支援,改多條等式。
3. `"""` 的縮排是「共同縮排」:某一行少縮一格,其他行的縮排就都會留下來。
4. 拿 `forall a ->` 當日常工具 → 應用碼用 `@T`,visible forall 是給 API 設計的。
5. 看到一堆 `{-# LANGUAGE #-}` 就想全部搬到 cabal → 只搬「每個檔案都要」的
   (`OverloadedStrings` 這種);語意重大的(`TypeFamilies`、`Strict`)留在檔案裡,
   讓讀者一眼知道這個模組有什麼特別。

## 2026 實務準則

1. 新專案 `default-language: GHC2024`,加上 `OverloadedStrings`、
   `OverloadedRecordDot`、`NoFieldSelectors` 三個全域擴充。
2. `\case`、`\cases`、`OrPatterns`、`MultilineStrings`:日常直接用,可讀性淨賺。
3. `RequiredTypeArguments`:寫函式庫 API 時考慮;讀到要認得。
4. `NamedDefaults`、`ExplicitLevelImports`:識讀即可。
5. 追新語法的原則:**有沒有取代掉一個更醜的舊寫法**?有才值得用。

## 習題

`exercises/Exercises/E10ModernSyntax.hs` → `cabal test level03-advanced`

`multiplier`(`\cases`)、`isMeta` 與 `parseCmd`(or-pattern)、
`helpText`(多行字串)、`boundsOf`(visible forall)。
擴充已在檔案頂端開好。
