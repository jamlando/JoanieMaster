-- Supabase Storage Setup for Joanie App
-- Run this in Supabase SQL Editor after creating the database schema

-- Create storage buckets (PRIVATE for security)
INSERT INTO storage.buckets (id, name, public) VALUES
    ('artwork-images', 'artwork-images', false),  -- SECURITY: Private bucket
    ('profile-photos', 'profile-photos', false);  -- SECURITY: Private bucket

-- Storage policies for artwork-images bucket (SECURE ACCESS CONTROL)
CREATE POLICY "Users can upload artwork images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own artwork images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update own artwork images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete own artwork images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Storage policies for profile-photos bucket (SECURE ACCESS CONTROL)
CREATE POLICY "Users can upload profile photos" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own profile photos" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update own profile photos" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete own profile photos" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );
