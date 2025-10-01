-- Joanie App Database Schema
-- Run this in Supabase SQL Editor after creating the project

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE user_role AS ENUM ('parent', 'guardian', 'viewer');
CREATE TYPE artwork_type AS ENUM ('drawing', 'painting', 'sculpture', 'writing', 'craft', 'other');
CREATE TYPE story_status AS ENUM ('draft', 'generated', 'published');

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    role user_role DEFAULT 'parent',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Children table
CREATE TABLE public.children (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    birth_date DATE,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Artwork uploads table
CREATE TABLE public.artwork_uploads (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    child_id UUID REFERENCES public.children(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT,
    description TEXT,
    artwork_type artwork_type DEFAULT 'drawing',
    image_url TEXT NOT NULL,
    thumbnail_url TEXT,
    file_size INTEGER,
    width INTEGER,
    height INTEGER,
    ai_analysis JSONB,
    tags TEXT[],
    is_favorite BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- AI-generated stories table
CREATE TABLE public.stories (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    child_id UUID REFERENCES public.children(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    artwork_ids UUID[] NOT NULL,
    status story_status DEFAULT 'draft',
    voice_url TEXT,
    pdf_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Family sharing table
CREATE TABLE public.family_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    family_id UUID NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    role user_role DEFAULT 'viewer',
    invited_by UUID REFERENCES public.users(id) ON DELETE CASCADE,
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(family_id, user_id)
);

-- Progress tracking table
CREATE TABLE public.progress_entries (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    child_id UUID REFERENCES public.children(id) ON DELETE CASCADE NOT NULL,
    skill_category TEXT NOT NULL,
    skill_level INTEGER CHECK (skill_level >= 1 AND skill_level <= 5),
    notes TEXT,
    artwork_id UUID REFERENCES public.artwork_uploads(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- COPPA compliance table (Children's Online Privacy Protection Act)
CREATE TABLE public.coppa_compliance (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    child_id UUID REFERENCES public.children(id) ON DELETE CASCADE NOT NULL,
    parental_consent_given BOOLEAN DEFAULT FALSE,
    consent_date TIMESTAMP WITH TIME ZONE,
    consent_method TEXT CHECK (consent_method IN ('email', 'phone', 'postal', 'digital_signature', 'video_call')),
    data_retention_period INTEGER DEFAULT 365, -- days
    ai_analysis_opt_in BOOLEAN DEFAULT FALSE,
    data_sharing_opt_in BOOLEAN DEFAULT FALSE,
    marketing_opt_in BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(child_id) -- One compliance record per child
);

-- Create indexes for better performance
CREATE INDEX idx_children_user_id ON public.children(user_id);
CREATE INDEX idx_artwork_uploads_child_id ON public.artwork_uploads(child_id);
CREATE INDEX idx_artwork_uploads_user_id ON public.artwork_uploads(user_id);
CREATE INDEX idx_artwork_uploads_created_at ON public.artwork_uploads(created_at DESC);
CREATE INDEX idx_stories_user_id ON public.stories(user_id);
CREATE INDEX idx_stories_child_id ON public.stories(child_id);
CREATE INDEX idx_family_members_family_id ON public.family_members(family_id);
CREATE INDEX idx_family_members_user_id ON public.family_members(user_id);
CREATE INDEX idx_progress_entries_child_id ON public.progress_entries(child_id);
CREATE INDEX idx_coppa_compliance_child_id ON public.coppa_compliance(child_id);
CREATE INDEX idx_coppa_compliance_user_id ON public.coppa_compliance(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.children ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.artwork_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coppa_compliance ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can only see and modify their own data
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Children policies
CREATE POLICY "Users can view own children" ON public.children
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own children" ON public.children
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own children" ON public.children
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own children" ON public.children
    FOR DELETE USING (auth.uid() = user_id);

-- Artwork uploads policies
CREATE POLICY "Users can view own artwork" ON public.artwork_uploads
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own artwork" ON public.artwork_uploads
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own artwork" ON public.artwork_uploads
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own artwork" ON public.artwork_uploads
    FOR DELETE USING (auth.uid() = user_id);

-- Stories policies
CREATE POLICY "Users can view own stories" ON public.stories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stories" ON public.stories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own stories" ON public.stories
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own stories" ON public.stories
    FOR DELETE USING (auth.uid() = user_id);

-- Family members policies
CREATE POLICY "Users can view family members" ON public.family_members
    FOR SELECT USING (
        auth.uid() = user_id OR 
        EXISTS (
            SELECT 1 FROM public.family_members fm2 
            WHERE fm2.family_id = family_members.family_id 
            AND fm2.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert family members" ON public.family_members
    FOR INSERT WITH CHECK (auth.uid() = invited_by);

CREATE POLICY "Users can update family members" ON public.family_members
    FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = invited_by);

-- Progress entries policies
CREATE POLICY "Users can view child progress" ON public.progress_entries
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.children c 
            WHERE c.id = child_id AND c.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert child progress" ON public.progress_entries
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.children c 
            WHERE c.id = child_id AND c.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update child progress" ON public.progress_entries
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.children c 
            WHERE c.id = child_id AND c.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete child progress" ON public.progress_entries
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.children c 
            WHERE c.id = child_id AND c.user_id = auth.uid()
        )
    );

-- COPPA compliance policies
CREATE POLICY "Users can view own COPPA compliance" ON public.coppa_compliance
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own COPPA compliance" ON public.coppa_compliance
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own COPPA compliance" ON public.coppa_compliance
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own COPPA compliance" ON public.coppa_compliance
    FOR DELETE USING (auth.uid() = user_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_children_updated_at BEFORE UPDATE ON public.children
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_artwork_uploads_updated_at BEFORE UPDATE ON public.artwork_uploads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stories_updated_at BEFORE UPDATE ON public.stories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_coppa_compliance_updated_at BEFORE UPDATE ON public.coppa_compliance
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for testing
INSERT INTO public.users (id, email, full_name, role) VALUES
    ('00000000-0000-0000-0000-000000000001', 'test@joanie.app', 'Test Parent', 'parent');

INSERT INTO public.children (id, user_id, name, birth_date) VALUES
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Test Child', '2020-01-01');
