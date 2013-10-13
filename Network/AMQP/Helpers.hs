{-# LANGUAGE ScopedTypeVariables #-}
module Network.AMQP.Helpers where

import Control.Concurrent
import Control.Monad
import System.Clock

import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as BL

toStrict :: BL.ByteString -> BS.ByteString
toStrict = BS.concat . BL.toChunks

toLazy :: BS.ByteString -> BL.ByteString
toLazy = BL.fromChunks . return

-- if the lock is open, calls to waitLock will immediately return.
-- if it is closed, calls to waitLock will block.
-- if the lock is killed, it will always be open and can't be closed anymore
data Lock = Lock (MVar Bool) (MVar ())

newLock :: IO Lock
newLock = liftM2 Lock (newMVar False) (newMVar ())

openLock :: Lock -> IO ()
openLock (Lock _ b) = void $ tryPutMVar b ()

closeLock :: Lock -> IO ()
closeLock (Lock a b) = withMVar a $ flip unless (void $ tryTakeMVar b)

waitLock :: Lock -> IO ()
waitLock (Lock _ b) = readMVar b

killLock :: Lock -> IO Bool
killLock (Lock a b) = do
    modifyMVar_ a $ const (return True)
    tryPutMVar b ()

chooseMin :: Ord a => a -> Maybe a -> a
chooseMin a (Just b) = min a b
chooseMin a Nothing  = a

getTimestamp :: IO Int
getTimestamp = fmap µs $ getTime Monotonic
  where
  	µs spec = (sec spec) * 1000 * 1000 + (nsec spec) `div` 1000

scheduleAtFixedRate :: Int -> IO () -> IO ThreadId
scheduleAtFixedRate interval_µs action = forkIO $ forever $ do
    action
    threadDelay interval_µs