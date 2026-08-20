-- Migration 0003: Captain Offers, Direct Requests and Conversation Linkage

-- 1. Create captain_offers table
CREATE TABLE IF NOT EXISTS public.captain_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "orderId" UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    "captainId" UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    "price" DOUBLE PRECISION NOT NULL,
    "estimatedTimeMinutes" INTEGER NOT NULL DEFAULT 30,
    "message" TEXT,
    "status" VARCHAR(32) NOT NULL DEFAULT 'pending',
    "isDirectRequest" BOOLEAN NOT NULL DEFAULT FALSE,
    "createdAt" TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    CONSTRAINT UQ_captain_offers_order_captain UNIQUE ("orderId", "captainId")
);

-- Index for quick lookup of offers by order
CREATE INDEX IF NOT EXISTS idx_captain_offers_orderId ON public.captain_offers("orderId");
CREATE INDEX IF NOT EXISTS idx_captain_offers_captainId ON public.captain_offers("captainId");

-- 2. Adjust conversations table unique constraint to (orderId, captainId)
ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_orderId_key;
DROP INDEX IF EXISTS conversations_orderId_key;
DROP INDEX IF EXISTS idx_conversations_order_captain;

-- Add offerId column to conversations if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='conversations' AND column_name='offerId') THEN
        ALTER TABLE public.conversations ADD COLUMN "offerId" UUID REFERENCES public.captain_offers(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create composite index for unique conversation per order+captain
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_order_captain ON public.conversations("orderId", "captainId");
