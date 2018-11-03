module Main where

import LoadImage

{--Error handling--}
import Control.Exception ( catch
                         , SomeException
                         )
{--State variables--}
import Data.IORef

{--GTK bindings--}
import Graphics.UI.Gtk
import Graphics.UI.Gtk.Gdk.PixbufAnimation
import System.Glib.UTFString

{--Needed for event handlers--}
import Control.Monad.IO.Class ( liftIO )

{--Concurrency--}
import Control.Concurrent ( forkIO
                          , ThreadId
                          , killThread
                          )
{--System buffer, for yanking filename--}
import System.Hclip

{- Portable filepath handling -}
import qualified  Filesystem.Path as FS
import qualified  Filesystem.Path.CurrentOS as FS.OS

{- Little things -}
import Data.Maybe
import Data.List ( findIndex )
import Data.Text ( unpack
                 , pack
                 , Text
                 )

fromString = pack

-- TODO:
-- Zooms needed*:
--  fit,
--  fill,
--  width+vscroll (maybe with '+' '-' and 'd' 's'),
--  free with scrollbars
-- *no zooms for animations
--
-- TODO
--  Add warning icon if file (animation) did not fit to window
--
-- TODO
--  Add "Cycle!" message on repeat
--  Need to either add counter or `watched` mask to Position, ugh
--
-- FIXME
--  Escape spaces when yanking
--
-- TODO
--  Dig into folder if it is alone in file list (initial!)

{- BEGIN Main -}
main :: IO ()
main = do
    {- Preparing list of files -}
    position <- initFileList
    printNumber position
    {- Creating GUI -}
    initGUI
    window  <- windowNew
    image   <- imageNewFromIconName "image-missing" IconSizeLargeToolbar
    overlay <- overlayNew
    overlayAdd overlay image
    containerAdd window overlay
    set window [ windowTitle := "My experiment"
               , containerBorderWidth := 0 ]
    {- Event handlers -}
    -- Exit
    on window objectDestroy mainQuit
    -- Keypresses
    on window keyPressEvent $ tryEvent $ do
        e <- eventModifier
        k <- eventKeyName
        liftIO $ keyWrapper e k position image
    -- Window resize
    on window configureEvent $ liftIO $ do
        redrawImage image position
    {- Initializing GUI -}
    widgetShowAll window
    -- Load first image
    nextImg nextRan position image
    -- Main GUI thread
    mainGUI
{- END Main -}

keyWrapper :: [Modifier] -> Text -> IORef Position -> Image -> IO ()
keyWrapper m c p i 
    |  q == "e"
    || q == "Right"
       = nextImg nextSeq p i

    |  q == "w"
    || q == "Left" 
       = nextImg prevSeq p i

    | q == "p" 
      = do
        x <- nameCopy p
        setClipboard x
        let y = FS.OS.encodeString $
                FS.filename $
                FS.OS.decodeString x
        putStrLn y

    |  q == "space"
    || q == "Return"
    || q == "Up"
       = nextImg nextRan p i

    |  q == "BackSpace"
    || q == "Down"
       = nextImg prevRan p i

    | q == "q"
    || q == "Escape"
       = mainQuit

    |  q == "y"
    || m == [ Control ] && q == "c"
       = nameCopy p >>= (\x -> putStrLn x >> setClipboard x)

    |  q == "0"
       = do
         ref <- readIORef p
         writeIORef p ( setZero ref )
         nextImg nextSeq p i

    | otherwise = return ()
  where q = unpack c

setZero :: Position -> Position
setZero p @ Position { ix_shuffle = shuf
                     , ix_rand    = ixr  }

    = p { ix_pos = -1
        , ix_rand = zz }

    where zz = fromMaybe ( error "error #4"       )
                         ( findIndex (==(0)) shuf )

printNumber :: IORef Position -> IO ()
printNumber a = do
    f <- readIORef a
    putStrLn $  "Opening "
             ++ show ( length $ files f )
             ++ " files"
