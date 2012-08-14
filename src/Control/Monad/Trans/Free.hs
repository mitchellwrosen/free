{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Control.Monad.Trans.Free
-- Copyright   :  (C) 2008-2012 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  MPTCs, fundeps
--
-- The free monad transformer
--
----------------------------------------------------------------------------
module Control.Monad.Trans.Free
  ( FreeT(..)
  , liftF
  ) where

import Control.Applicative
import Control.Monad (liftM, MonadPlus(..), ap)
import Control.Monad.Trans.Class
import Control.Monad.Free.Class
import Control.Monad.IO.Class
import Data.Monoid
import Data.Foldable
import Data.Traversable
import Data.Bifunctor
import Data.Bifoldable
import Data.Bitraversable

data FreeF f a b = Pure a | Free (f b)
  deriving (Eq,Ord,Show,Read)

instance Functor f => Functor (FreeF f a) where
  fmap _ (Pure a)  = Pure a
  fmap f (Free as) = Free (fmap f as)

instance Foldable f => Foldable (FreeF f a) where
  foldMap f (Free as) = foldMap f as
  foldMap _ _         = mempty

instance Traversable f => Traversable (FreeF f a) where
  traverse _ (Pure a)  = pure (Pure a)
  traverse f (Free as) = Free <$> traverse f as

instance Functor f => Bifunctor (FreeF f) where
  bimap f _ (Pure a)  = Pure (f a)
  bimap _ g (Free as) = Free (fmap g as)

instance Foldable f => Bifoldable (FreeF f) where
  bifoldMap f _ (Pure a)  = f a
  bifoldMap _ g (Free as) = foldMap g as

instance Traversable f => Bitraversable (FreeF f) where
  bitraverse f _ (Pure a)  = Pure <$> f a
  bitraverse _ g (Free as) = Free <$> traverse g as

newtype FreeT f m a = FreeT { runFreeT :: m (FreeF f a (FreeT f m a)) }

instance Eq (m (FreeF f a (FreeT f m a))) => Eq (FreeT f m a) where
  FreeT m == FreeT n = m == n

instance Ord (m (FreeF f a (FreeT f m a))) => Ord (FreeT f m a) where
  compare (FreeT m) (FreeT n) = compare m n

instance Show (m (FreeF f a (FreeT f m a))) => Show (FreeT f m a) where
  showsPrec d (FreeT m) = showParen (d > 10) $
    showString "FreeT " . showsPrec 11 m

instance Read (m (FreeF f a (FreeT f m a))) => Read (FreeT f m a) where
  readsPrec d =  readParen (d > 10) $ \r ->
    [ (FreeT m,t) | ("FreeT",s) <- lex r, (m,t) <- readsPrec 11 s]

instance (Functor f, Monad m) => Functor (FreeT f m) where
  fmap f (FreeT m) = FreeT (liftM f' m) where
    f' (Pure a)  = Pure (f a)
    f' (Free as) = Free (fmap (fmap f) as)

instance (Functor f, Monad m) => Applicative (FreeT f m) where
  pure a = FreeT (return (Pure a))
  (<*>) = ap

instance (Functor f, Monad m) => Monad (FreeT f m) where
  return a = FreeT (return (Pure a))
  FreeT m >>= f = FreeT $ m >>= \v -> case v of
    Pure a -> runFreeT (f a)
    Free w -> return (Free (fmap (>>= f) w))

instance MonadTrans (FreeT f) where
  lift = FreeT . liftM Pure

instance (Functor f, MonadIO m) => MonadIO (FreeT f m) where
  liftIO = lift . liftIO

instance (Functor f, MonadPlus m) => Alternative (FreeT f m) where
  empty = FreeT mzero
  FreeT ma <|> FreeT mb = FreeT (mplus ma mb)

instance (Functor f, MonadPlus m) => MonadPlus (FreeT f m) where
  mzero = FreeT mzero
  mplus (FreeT ma) (FreeT mb) = FreeT (mplus ma mb)

instance (Functor f, Monad m) => MonadFree f (FreeT f m) where
  wrap = FreeT . return . Free

liftF :: (Functor f, Monad m) => f a -> FreeT f m a
liftF = wrap . fmap return

instance (Foldable m, Foldable f) => Foldable (FreeT f m) where
  foldMap f (FreeT m) = foldMap (bifoldMap f (foldMap f)) m

instance (Monad m, Traversable m, Traversable f) => Traversable (FreeT f m) where
  traverse f (FreeT m) = FreeT <$> traverse (bitraverse f (traverse f)) m