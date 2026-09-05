{-# LANGUAGE MultilineStrings #-}
{-# LANGUAGE OrPatterns #-}
{-# LANGUAGE RequiredTypeArguments #-}

-- | 第 8 章習題:GHC 9.10–9.14 的新語法(參考解答)
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

-- | 屬性相剋表:\cases 一次比對兩個引數。
multiplier :: Element -> Element -> Double
multiplier = \cases
  Fire Grass -> 2
  Grass Ice -> 2
  Ice Fire -> 2
  Grass Fire -> 0.5
  Ice Grass -> 0.5
  Fire Ice -> 0.5
  _ _ -> 1

data Cmd = Go Text | Look | Help | Version | Quit
  deriving stock (Eq, Show)

-- | 「不影響遊戲狀態」的指令:or-pattern 把幾個建構子寫在同一個分支。
isMeta :: Cmd -> Bool
isMeta (Help; Version; Quit) = True
isMeta _ = False

-- | 解析指令,同義詞用 or-pattern 合併。
parseCmd :: Text -> Maybe Cmd
parseCmd t = case T.words (T.toLower t) of
  ["go", dir] -> Just (Go dir)
  (["look"]; ["l"]) -> Just Look
  (["help"]; ["h"]; ["?"]) -> Just Help
  (["version"]; ["v"]) -> Just Version
  (["quit"]; ["q"]; ["exit"]) -> Just Quit
  _ -> Nothing

-- | 多行字串:共同縮排會被拿掉,開頭與結尾的換行也會被拿掉。
helpText :: Text
helpText =
  """
  指令:
    go <方向>  移動
    look       觀察四周
    help       這份說明
    quit       離開
  """

-- | 必填型別引數:呼叫時直接寫型別,boundsOf Bool、boundsOf Element。
boundsOf :: forall a -> (Bounded a, Show a) => Text
boundsOf a = T.pack (show (minBound :: a)) <> " .. " <> T.pack (show (maxBound :: a))
