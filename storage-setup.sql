-- Supabase Storage Setup for Joanie App
-- Run this in Supabase SQL Editor after creating the database schema

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES
    ('artwork-images', 'artwork-images', true),
    ('profile-photos', 'profile-photos', true);

-- Storage policies for artwork-images bucket
CREATE POLICY "Users can upload artwork images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Users can view artwork images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Users can update artwork images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Users can delete artwork images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'artwork-images' AND
        auth.role() = 'authenticated'
    );

-- Storage policies for profile-photos bucket
CREATE POLICY "Users can upload profile photos" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Users can view profile photos" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Users can update profile photos" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated'
    );

CREATE POLICY "Users can delete profile photos" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profile-photos' AND
        auth.role() = 'authenticated'
    );
