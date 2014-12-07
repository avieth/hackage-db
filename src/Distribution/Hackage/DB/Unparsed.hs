{- |
   Module      :  Distribution.Hackage.DB.Unparsed
   License     :  BSD3
   Maintainer  :  simons@cryp.to
   Stability   :  provisional
   Portability :  portable

   This module provides simple access to the Hackage database by means
   of 'Map'.
 -}

module Distribution.Hackage.DB.Unparsed
  ( Hackage, readHackage, readHackage', parseHackage, hackagePath
  )
  where

import qualified Codec.Archive.Tar as Tar
import Data.ByteString.Lazy.Char8 ( ByteString )
import qualified Data.ByteString.Lazy.Char8 as BS8 ( readFile )
import Data.Map
import Data.Maybe ( fromMaybe )
import Data.Version
import Distribution.Text ( simpleParse )
import System.Directory ( getHomeDirectory )
import System.FilePath ( joinPath, splitDirectories )

-- | A 'Map' representation of the Hackage database. Every package name
-- maps to a non-empty set of version, and for every version there is a
-- Cabal file stored as a (lazy) 'ByteString'.

type Hackage = Map String (Map Version ByteString)

-- | Read the Hackage database from the location determined by 'hackagePath'
-- and return a 'Map' that provides fast access to its contents.

readHackage :: IO Hackage
readHackage = hackagePath >>= readHackage'

-- | Read the Hackage database from the given 'FilePath' and return a
-- 'Hackage' map that provides fast access to its contents.

readHackage' :: FilePath -> IO Hackage
readHackage' = fmap parseHackage . BS8.readFile

-- | Parse the contents of Hackage's @00-index.tar@ into a 'Hackage' map.

parseHackage :: ByteString -> Hackage
parseHackage = Tar.foldEntries addEntry empty (error . show) . Tar.read
  where
    addEntry :: Tar.Entry -> Hackage -> Hackage
    addEntry e db = case splitDirectories (Tar.entryPath e) of
                        [".",".","@LongLink"] -> db
                        path@[name,vers,_] -> case Tar.entryContent e of
                                                Tar.NormalFile buf _ -> add name vers buf db
                                                _                    -> error ("Hackage.DB.parseHackage: unexpected content type for " ++ show path)
                        _                  -> db

    add :: String -> String -> ByteString -> Hackage -> Hackage
    add name version pkg = insertWith union name (singleton (pVersion version) pkg)

    pVersion :: String -> Version
    pVersion str = fromMaybe (error $ "Hackage.DB.parseHackage: cannot parse version " ++ show str) (simpleParse str)

-- | Determine the default path of the Hackage database, which typically
-- resides at @"$HOME\/.cabal\/packages\/hackage.haskell.org\/00-index.tar"@.
-- Running the command @"cabal update"@ will keep that file up-to-date.

hackagePath :: IO FilePath
hackagePath = do
  homedir <- getHomeDirectory
  return $ joinPath [homedir, ".cabal", "packages", "hackage.haskell.org", "00-index.tar"]