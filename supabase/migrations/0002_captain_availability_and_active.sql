-- ============================================================
-- Migration 0002: Captain Availability & Active Status
-- Adds isActive column to captain_profiles & creates captain_availability table
-- ============================================================

-- 1. Ensure columns exist on captain_profiles
ALTER TABLE public.captain_profiles ADD COLUMN IF NOT EXISTS "isActive" boolean NOT NULL DEFAULT true;
ALTER TABLE public.captain_profiles ADD COLUMN IF NOT EXISTS "nationalIdCardImageUrl" text;
ALTER TABLE public.captain_profiles ADD COLUMN IF NOT EXISTS "licenseImageUrl" text;

-- 2. Create captain_availability table
CREATE TABLE IF NOT EXISTS public.captain_availability (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  "captainId" uuid NOT NULL,
  "currentLat" double precision NOT NULL,
  "currentLng" double precision NOT NULL,
  "currentAddress" text,
  "vehicleType" text NOT NULL DEFAULT 'car',
  "deliveryRadiusKm" double precision NOT NULL DEFAULT 10.0,
  "isAvailable" boolean NOT NULL DEFAULT true,
  "createdAt" timestamp without time zone NOT NULL DEFAULT now(),
  "updatedAt" timestamp without time zone NOT NULL DEFAULT now(),
  "expiresAt" timestamp without time zone NOT NULL DEFAULT (now() + interval '8 hours'),
  CONSTRAINT "PK_captain_availability" PRIMARY KEY (id),
  CONSTRAINT "FK_captain_availability_captain" FOREIGN KEY ("captainId") REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT "UQ_captain_availability_captain" UNIQUE ("captainId")
);

ALTER TABLE public.captain_availability OWNER TO postgres;

CREATE INDEX IF NOT EXISTS "IDX_captain_availability_lookup" 
ON public.captain_availability ("isAvailable", "expiresAt", "currentLat", "currentLng");

-- 3. RLS Policies for captain_availability
ALTER TABLE public.captain_availability ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "availability_select_all" ON public.captain_availability;
CREATE POLICY "availability_select_all" ON public.captain_availability
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "availability_insert_captain" ON public.captain_availability;
CREATE POLICY "availability_insert_captain" ON public.captain_availability
  FOR INSERT WITH CHECK ("captainId" = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "availability_update_captain" ON public.captain_availability;
CREATE POLICY "availability_update_captain" ON public.captain_availability
  FOR UPDATE USING ("captainId" = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "availability_delete_captain" ON public.captain_availability;
CREATE POLICY "availability_delete_captain" ON public.captain_availability
  FOR DELETE USING ("captainId" = auth.uid() OR public.is_admin());

-- 4. Trigger for updated_at
DROP TRIGGER IF EXISTS trg_captain_availability_updated_at ON public.captain_availability;
CREATE TRIGGER trg_captain_availability_updated_at BEFORE UPDATE ON public.captain_availability
  for EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 5. Add to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.captain_availability;
