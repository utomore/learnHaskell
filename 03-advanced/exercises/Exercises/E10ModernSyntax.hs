{-# LANGUAGE MultilineStrings #-}
{-# LANGUAGE OrPatterns #-}
{-# LANGUAGE RequiredTypeArguments #-}

-- | 第 8 章習題:GHC 9.10–9.14 的新語法
--
-- 把 undefined 換成實作 → cabal test level03-advanced
module Exercises.E10ModernSyntax
  ( Element (..)
  , Cmd (..)
  , multiplier
  , isMeta
  , parseCmd
  , helpText
  , boundsOf
  ) where

import Data.Text (Text)
import Data.Text qualified as T

data Element = Fire | Ice | Grass
  deriving stock (Eq, Show, Enum, Bounded)

-- | 屬性相剋表,用 \cases 一次比對兩個引數:
--
-- * Fire 剋 Grass、Grass 剋 Ice、Ice 剋 Fire → 2
-- * 反過來被剋 → 0.5
-- * 其他(含同屬性)→ 1
multiplier :: Element -> Element -> Double
multiplier = undefined

data Cmd = Go Text | Look | Help | Version | Quit
  deriving stock (Eq, Show)

-- | 「不影響遊戲狀態」的指令:Help、Version、Quit。
-- 用 or-pattern 寫成一個分支:isMeta (Help; Version; Quit) = True
isMeta :: Cmd -> Bool
isMeta = undefined

-- | 解析指令(大小寫不分),同義詞用 or-pattern 合併:
--
-- * "go <dir>"               → Go dir
-- * "look" / "l"             → Look
-- * "help" / "h" / "?"       → Help
-- * "version" / "v"          → Version
-- * "quit" / "q" / "exit"    → Quit
-- * 其他                     → Nothing
--
-- 提示:case T.words (T.toLower t) of (["look"]; ["l"]) -> ...
-- (or-pattern 外面要加括號。)
parseCmd :: Text -> Maybe Cmd
parseCmd = undefined

-- | 多行字串:把說明寫成 """ ... """。
-- 測試會檢查它有 5 行、第一行是「指令:」、共同縮排已被移除
-- (第二行以「  go」開頭,兩個空白)。
helpText :: Text
helpText = undefined

-- | 必填型別引數:boundsOf Bool == "False .. True"。
-- 提示:boundsOf a = ... (minBound :: a) ... (maxBound :: a)
boundsOf :: forall a -> (Bounded a, Show a) => Text
boundsOf _ = undefined
