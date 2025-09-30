# Supabase Setup Guide for Joanie App

## Prerequisites
- Supabase account (free tier available)
- iOS development environment with Xcode

## Step 1: Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click "New Project"
3. Fill in project details:
   - **Name**: `joanie-app`
   - **Database Password**: Generate a strong password (save this!)
   - **Region**: Choose closest to your users
4. Click "Create new project"
5. Wait for project to be ready (2-3 minutes)

## Step 2: Get Project Credentials

1. In your Supabase dashboard, go to **Settings** → **API**
2. Copy these values:
   - **Project URL**: `https://[project-id].supabase.co`
   - **Anon Key**: `[anon-key]`
   - **Service Role Key**: `[service-role-key]` (keep secret)

## Step 3: Configure iOS App

1. Open `Joanie/Utils/Config.swift`
2. Replace the placeholder values:
   ```swift
   static let supabaseURL = "https://your-project-id.supabase.co"
   static let supabaseAnonKey = "your-anon-key"
   ```
   With your actual values:
   ```swift
   static let supabaseURL = "https://[your-project-id].supabase.co"
   static let supabaseAnonKey = "[your-anon-key]"
   ```

## Step 4: Set Up Database Schema

1. In Supabase dashboard, go to **SQL Editor**
2. Copy and paste the contents of `database-schema.sql`
3. Click "Run" to execute the schema
4. Verify tables were created in **Table Editor**

## Step 5: Set Up Storage

1. In Supabase dashboard, go to **SQL Editor**
2. Copy and paste the contents of `storage-setup.sql`
3. Click "Run" to execute the storage setup
4. Verify buckets were created in **Storage**

## Step 6: Configure Authentication

1. In Supabase dashboard, go to **Authentication** → **Settings**
2. Configure **Site URL**: `https://your-domain.com` (for production)
3. Add **Redirect URLs** as needed
4. Enable **Email** provider (enabled by default)
5. For Apple Sign-In (optional):
   - Go to **Authentication** → **Providers**
   - Enable **Apple** provider
   - Configure with Apple Developer credentials

## Step 7: Test Configuration

1. Build and run the iOS app
2. The app will automatically test the Supabase connection
3. Check console output for test results
4. All tests should pass if configuration is correct

## Step 8: Environment Variables (Production)

For production deployment, use environment variables instead of hardcoded values:

```swift
static let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://your-project-id.supabase.co"
static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "your-anon-key"
```

## Troubleshooting

### Common Issues

1. **"Invalid Supabase URL" error**
   - Check that the URL is correct and includes `https://`
   - Ensure the project ID is correct

2. **"Invalid API key" error**
   - Verify you're using the **Anon Key**, not the Service Role Key
   - Check for extra spaces or characters

3. **"Table doesn't exist" error**
   - Run the database schema SQL script
   - Check that tables were created in Table Editor

4. **"Bucket doesn't exist" error**
   - Run the storage setup SQL script
   - Check that buckets were created in Storage

5. **Authentication errors**
   - Check that email provider is enabled
   - Verify redirect URLs are configured correctly

### Getting Help

- Check Supabase documentation: [supabase.com/docs](https://supabase.com/docs)
- Join Supabase Discord: [discord.supabase.com](https://discord.supabase.com)
- Check project logs in Supabase dashboard

## Security Notes

- Never commit API keys to version control
- Use environment variables for production
- Keep Service Role Key secret
- Enable Row Level Security (RLS) policies
- Regularly rotate API keys

## Next Steps

After successful setup:
1. Test user registration and login
2. Test artwork upload functionality
3. Test story generation features
4. Configure push notifications
5. Set up analytics and monitoring
