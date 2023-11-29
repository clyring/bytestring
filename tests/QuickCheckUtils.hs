{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeApplications #-}

module QuickCheckUtils
  ( Char8(..)
  , String8(..)
  , CByteString(..)
  , Sqrt(..)
  ) where

import Test.Tasty.QuickCheck
import Text.Show.Functions

import Control.Monad        ( liftM2 )
import Data.Char
import Data.Word
import Data.Int
import System.IO
import Foreign.C (CChar)

import qualified Data.ByteString.Short as SB
import qualified Data.ByteString      as P
import qualified Data.ByteString.Lazy as L

import qualified Data.ByteString.Char8      as PC
import qualified Data.ByteString.Lazy.Char8 as LC

------------------------------------------------------------------------

sizedByteString n = do m <- choose(0, n)
                       fmap P.pack $ vectorOf m arbitrary

instance Arbitrary P.ByteString where
  arbitrary = do
    bs <- sized sizedByteString
    n  <- choose (0, 2)
    return (P.drop n bs) -- to give us some with non-0 offset
  shrink = map P.pack . shrink . P.unpack

instance CoArbitrary P.ByteString where
  coarbitrary s = coarbitrary (P.unpack s)

instance Arbitrary L.ByteString where
  arbitrary = sized $ \n -> do numChunks <- choose (0, n)
                               if numChunks == 0
                                   then return L.empty
                                   else fmap (L.fromChunks .
                                              filter (not . P.null)) $
                                            vectorOf numChunks
                                                     (sizedByteString
                                                          (n `div` numChunks))

instance CoArbitrary L.ByteString where
  coarbitrary s = coarbitrary (L.unpack s)

newtype CByteString = CByteString P.ByteString
  deriving Show

instance Arbitrary CByteString where
  arbitrary = fmap (CByteString . P.pack . map fromCChar)
                   arbitrary
    where
      fromCChar :: NonZero CChar -> Word8
      fromCChar = fromIntegral . getNonZero

-- | 'Char', but only representing 8-bit characters.
--
newtype Char8 = Char8 Char
  deriving (Eq, Ord, Show)

instance Arbitrary Char8 where
  arbitrary = fmap (Char8 . toChar) arbitrary
    where
      toChar :: Word8 -> Char
      toChar = toEnum . fromIntegral
  shrink (Char8 c) = fmap Char8 (shrink c)

instance CoArbitrary Char8 where
  coarbitrary (Char8 c) = coarbitrary c

-- | 'Char', but only representing 8-bit characters.
--
newtype String8 = String8 String
  deriving (Eq, Ord, Show)

instance Arbitrary String8 where
  arbitrary = fmap (String8 . map toChar) arbitrary
    where
      toChar :: Word8 -> Char
      toChar = toEnum . fromIntegral
  shrink (String8 xs) = fmap String8 (shrink xs)

-- | If a test takes O(n^2) time or memory, it's useful to wrap its inputs
-- into 'Sqrt' so that increasing number of tests affects run time linearly.
newtype Sqrt a = Sqrt { unSqrt :: a }
  deriving (Eq, Show)

instance Arbitrary a => Arbitrary (Sqrt a) where
  arbitrary = Sqrt <$> sized
    (\n -> resize (round @Double $ sqrt $ fromIntegral @Int n) arbitrary)
  shrink = map Sqrt . shrink . unSqrt


sizedShortByteString :: Int -> Gen SB.ShortByteString
sizedShortByteString n = do m <- choose(0, n)
                            fmap SB.pack $ vectorOf m arbitrary

instance Arbitrary SB.ShortByteString where
  arbitrary = sized sizedShortByteString
  shrink = map SB.pack . shrink . SB.unpack

instance CoArbitrary SB.ShortByteString where
  coarbitrary s = coarbitrary (SB.unpack s)

instance {-# OVERLAPPING #-} Testable (Int64 -> prop) where
  property = error $ unlines [
    "Found a test taking a raw Int64 argument.",
    "'instance Arbitrary Int64' by default is likely to",
    "produce very large numbers after the first few tests,",
    "which doesn't make great indices into a LazyByteString.",
    "For indices, try 'intToIndexTy' in Properties/ByteString.hs.",
    "",
    "If very few small-numbers tests is OK,",
    "use 'forAllShrink' to bypass this poison instance."]
