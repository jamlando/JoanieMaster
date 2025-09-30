# Supabase Configuration for Joanie App

## Project Setup Instructions

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Sign in or create account
3. Click "New Project"
4. Choose organization
5. Project name: `joanie-app`
6. Database password: [Generate strong password]
7. Region: [Choose closest to users]
8. Click "Create new project"

### 2. Get Project Credentials
After project creation, note these values:
- Project URL: `https://[project-id].supabase.co`
- Anon Key: `[anon-key]`
- Service Role Key: `[service-role-key]` (keep secret)

### 3. Database Schema
See `database-schema.sql` for complete schema

### 4. Storage Buckets
- `artwork-images` - For child artwork photos
- `profile-photos` - For child profile pictures

### 5. Authentication Providers
- Email/Password (enabled by default)
- Apple Sign-In (requires Apple Developer configuration)

## Environment Variables
Add to iOS app configuration:
```
SUPABASE_URL=https://[project-id].supabase.co
SUPABASE_ANON_KEY=[anon-key]
```
