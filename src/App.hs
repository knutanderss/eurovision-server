{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE TypeFamilies      #-}
{-# LANGUAGE TypeOperators     #-}

module App where

import           Control.Monad.IO.Class         ( liftIO )
import           Control.Monad.Logger           ( runStderrLoggingT )
import           Database.Persist.Sqlite        ( ConnectionPool
                                                , createSqlitePool
                                                , runSqlPool
                                                , runSqlPersistMPool
                                                , runMigration
                                                , selectFirst
                                                , (==.)
                                                , insert
                                                , entityVal
                                                )
import           Data.String.Conversions        ( cs )
import           Data.Text                      ( Text )
import           Network.Wai.Handler.Warp      as Warp
import           Control.Applicative
import           Servant
import           Data.Maybe
import           System.Environment
import           Safe

import           Api
import           Models


server :: ConnectionPool -> Server Api
server pool = userAddH :<|> userGetH
 where
  userAddH newUser = liftIO $ userAdd newUser
  userGetH name = liftIO $ userGet name

  userAdd :: User -> IO (Maybe (Key User))
  userAdd newUser = flip runSqlPersistMPool pool $ do
    exists <- selectFirst [UserName ==. userName newUser] []
    case exists of
      Nothing -> Just <$> insert newUser
      Just _  -> return Nothing

  userGet :: Text -> IO (Maybe User)
  userGet name = flip runSqlPersistMPool pool $ do
    mUser <- selectFirst [UserName ==. name] []
    return $ entityVal <$> mUser

app :: ConnectionPool -> Application
app pool = serve api $ server pool

mkApp :: FilePath -> IO Application
mkApp sqliteFile = do
  pool <- runStderrLoggingT $ createSqlitePool (cs sqliteFile) 5

  runSqlPool (runMigration migrateAll) pool
  return $ app pool

run :: FilePath -> IO ()
run sqliteFile = do 
  port <- lookupPort
  Warp.run port =<< mkApp sqliteFile

lookupPort :: IO Int
lookupPort =
  (readDef 3000 . fromMaybe "3000") <$> lookupEnv "PORT" 