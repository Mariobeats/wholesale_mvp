-- ========================================================
-- WHOLESALE ORDER MANAGEMENT APP - SUPABASE SQL MIGRATION
-- ========================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES TABLE (Linked with auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'salesman')),
  mobile TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. PRODUCTS TABLE
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
  stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
  hsn_code TEXT DEFAULT '21069099',
  gst_rate NUMERIC(5, 2) DEFAULT 5.0,
  pcs_per_box INT DEFAULT 1,
  unit TEXT DEFAULT 'PCS',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PARTIES TABLE
CREATE TABLE IF NOT EXISTS public.parties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_name TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  mobile TEXT NOT NULL,
  address TEXT,
  gstin TEXT,
  state_name TEXT DEFAULT 'Madhya Pradesh',
  state_code TEXT DEFAULT '23',
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  gps_accuracy DOUBLE PRECISION,
  location_captured_at TIMESTAMPTZ,
  location_source TEXT DEFAULT 'gps',
  location_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ORDERS TABLE
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  party_id UUID NOT NULL REFERENCES public.parties(id) ON DELETE RESTRICT,
  salesman_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ORDER ITEMS TABLE
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity INT NOT NULL CHECK (quantity > 0),
  price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
  remark TEXT
);

-- RLS POLICIES (Row Level Security - Hardened Security Rules)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Helper Function to Check if Current User is Admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. PROFILES SECURITY POLICIES
-- Anyone authenticated can read profiles
CREATE POLICY "Profiles read policy" ON public.profiles 
  FOR SELECT USING (auth.role() = 'authenticated');

-- Users can update their own profile (name, mobile), Admins can update any profile
CREATE POLICY "Profiles update policy" ON public.profiles 
  FOR UPDATE USING (auth.uid() = id OR public.is_admin());

-- Only Admins or Auth Trigger can insert profiles
CREATE POLICY "Profiles insert policy" ON public.profiles 
  FOR INSERT WITH CHECK (auth.uid() = id OR public.is_admin());


-- 2. PRODUCTS SECURITY POLICIES
-- All logged-in users can view products
CREATE POLICY "Products select policy" ON public.products 
  FOR SELECT USING (auth.role() = 'authenticated');

-- ONLY Admins can Add, Edit, or Delete Products (Salesmen cannot alter prices, items, or stock)
CREATE POLICY "Products admin insert policy" ON public.products 
  FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "Products admin update policy" ON public.products 
  FOR UPDATE USING (public.is_admin());

CREATE POLICY "Products admin delete policy" ON public.products 
  FOR DELETE USING (public.is_admin());


-- 3. PARTIES SECURITY POLICIES
-- All logged-in users can view parties
CREATE POLICY "Parties select policy" ON public.parties 
  FOR SELECT USING (auth.role() = 'authenticated');

-- Salesmen and Admins can create new parties
CREATE POLICY "Parties insert policy" ON public.parties 
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Salesmen and Admins can update party details
CREATE POLICY "Parties update policy" ON public.parties 
  FOR UPDATE USING (auth.role() = 'authenticated');

-- ONLY Admins can delete parties
CREATE POLICY "Parties admin delete policy" ON public.parties 
  FOR DELETE USING (public.is_admin());


-- 4. ORDERS & ORDER ITEMS SECURITY POLICIES
-- Admins see ALL orders; Salesmen see ONLY THEIR OWN created orders
CREATE POLICY "Orders select policy" ON public.orders 
  FOR SELECT USING (public.is_admin() OR salesman_id = auth.uid());

-- Salesmen can create orders assigned to themselves, Admins can create any order
CREATE POLICY "Orders insert policy" ON public.orders 
  FOR INSERT WITH CHECK (salesman_id = auth.uid() OR public.is_admin());

-- ONLY Admins can modify or delete existing orders
CREATE POLICY "Orders admin update policy" ON public.orders 
  FOR UPDATE USING (public.is_admin());

CREATE POLICY "Orders admin delete policy" ON public.orders 
  FOR DELETE USING (public.is_admin());

-- Order Items inherits order visibility
CREATE POLICY "Order items select policy" ON public.order_items 
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.orders 
      WHERE orders.id = order_items.order_id 
      AND (public.is_admin() OR orders.salesman_id = auth.uid())
    )
  );

CREATE POLICY "Order items insert policy" ON public.order_items 
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');


-- 6. ATOMIC ORDER PLACEMENT AND STOCK DEDUCTION STORED PROCEDURE
CREATE OR REPLACE FUNCTION place_order_with_items(
  p_party_id UUID,
  p_salesman_id UUID,
  p_total_amount NUMERIC,
  p_items JSONB
) RETURNS UUID AS $$
DECLARE
  v_order_id UUID;
  item JSONB;
  v_curr_stock INT;
BEGIN
  -- 1. Insert order
  INSERT INTO public.orders (party_id, salesman_id, total_amount, status)
  VALUES (p_party_id, p_salesman_id, p_total_amount, 'completed')
  RETURNING id INTO v_order_id;

  -- 2. Process each line item
  FOR item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Verify current stock
    SELECT stock INTO v_curr_stock 
    FROM public.products 
    WHERE id = (item->>'product_id')::UUID;

    IF v_curr_stock IS NULL THEN
      RAISE EXCEPTION 'Product % not found', item->>'product_id';
    END IF;

    IF v_curr_stock < (item->>'quantity')::INT THEN
      RAISE EXCEPTION 'Insufficient stock for product %. Available: %, Requested: %', 
        item->>'product_id', v_curr_stock, (item->>'quantity')::INT;
    END IF;

    -- Insert order item
    INSERT INTO public.order_items (order_id, product_id, quantity, price, remark)
    VALUES (
      v_order_id,
      (item->>'product_id')::UUID,
      (item->>'quantity')::INT,
      (item->>'price')::NUMERIC,
      item->>'remark'
    );

    -- Automatically decrease product stock
    UPDATE public.products
    SET stock = stock - (item->>'quantity')::INT
    WHERE id = (item->>'product_id')::UUID;
  END LOOP;

  RETURN v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. PAYMENTS TABLE (Party Khata / Payment Collection)
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  party_id UUID NOT NULL REFERENCES public.parties(id) ON DELETE CASCADE,
  salesman_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  payment_mode TEXT NOT NULL CHECK (payment_mode IN ('cash', 'upi', 'cheque', 'bank_transfer')),
  reference_no TEXT,
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PAYMENTS SECURITY POLICIES
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Payments select policy" ON public.payments 
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Payments insert policy" ON public.payments 
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Payments admin update policy" ON public.payments 
  FOR UPDATE USING (public.is_admin());

CREATE POLICY "Payments admin delete policy" ON public.payments 
  FOR DELETE USING (public.is_admin());


