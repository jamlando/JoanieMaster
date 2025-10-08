# Resend API Production Configuration Guide

## Overview

This guide covers the complete setup and configuration of Resend email service for production deployment of the Joanie iOS app.

## Prerequisites

1. **Resend Account**: Create a production-ready Resend account at [resend.com](https://resend.com)
2. **API Key**: Generate a production API key from your Resend dashboard
3. **Domain Verification**: Verify your custom domain for sending emails
4. **DNS Records**: Configure proper DNS records for your domain

## Environment Variables Configuration

### Required Variables

Set these environment variables in your production environment:

```bash
# Core Resend Configuration
RESEND_API_KEY=re_your_production_api_key_here
RESEND_DOMAIN=yourdomain.com
RESEND_API_BASE_URL=https://api.resend.com

# Email Addresses
EMAIL_FROM_ADDRESS=noreply@yourdomain.com
EMAIL_FROM_NAME=YourAppName
RESEND_MARKETING_FROM=hello@yourdomain.com
RESEND_SUPPORT_FROM=support@yourdomain.com
RESEND_NOREPLY_FROM=noreply@yourdomain.com

# Service Settings
EMAIL_SERVICE_PROVIDER=resend
RESEND_EMAIL_ENABLED=true
EMAIL_FALLBACK_ENABLED=true

# Production Settings
APP_ENVIRONMENT=production
RESEND_TIMEOUT_SECONDS=45
RESEND_MAX_RETRIES=5
RESEND_ENABLE_SSL=true
```

### Optional Configuration

```bash
# Advanced Settings
DEBUG_MODE=false
RESEND_USER_AGENT=YourApp-iOS/1.0.0

# Monitoring & Analytics (if applicable)
ANALYTICS_ENABLED=true
EMAIL_ANALYTICS_SERVICE=enabled
```

## Domain Setup

### 1. Add Domain in Resend Dashboard

1. Log into your Resend dashboard
2. Navigate to "Domains" section
3. Add your custom domain (e.g., `yourdomain.com`)
4. Follow the DNS configuration instructions

### 2. Configure DNS Records

Add these DNS records to your domain registrar:

```dns
# SPF Record
v=spf1include:_spf.resend.com ~all

# DKIM Record (provided by Resend)
resend._domainkey.yourdomain.com CNAME resend1._domainkey.resend.com

# DMARC Record
_dmarc.yourdomain.com TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"

# Return-Path (from Resend)
bounce.yourdomain.com CNAME resend.com
```

### 3. Verify Domain

After adding DNS records:
1. Wait 5-10 minutes for DNS propagation
2. Click "Verify" in your Resend dashboard
3. Confirm all checks pass (SPF, DKIM, DMARC, MX)

## Production Deployment Checklist

### Pre-Deployment

- [ ] Environment variables configured
- [ ] Resend API key obtained and set
- [ ] Domain verified in Resend dashboard
- [ ] DNS records properly configured
- [ ] SSL certificates valid for your domain

### Security Verification

- [ ] API key is stored securely (environment variables)
- [ ] No API keys in source code or logs
- [ ] Production environment flags set correctly
- [ ] SSL/TLS enabled (`RESEND_ENABLE_SSL=true`)

### Testing Configuration

```bash
# Test API connection
curl -X GET "https://api.resend.com/domains" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Accept: application/json"

# Test email sending
curl -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "noreply@yourdomain.com",
    "to": ["test@example.com"],
    "subject": "Production Test",
    "text": "This is a test email from production"
  }'
```

## Monitoring and Logging

### Production Monitoring

The configuration automatically enables:
- Request tracking with unique IDs
- Response time monitoring
- Error categorization and logging
- Production environment headers

### Log Levels

In production, configure appropriate log levels:
- **ERROR**: API failures, authentication issues
- **WARN**: Rate limiting, retry attempts
- **INFO**: Successful sends, performance metrics
- **DEBUG**: Detailed request/response (development only)

### Metrics to Monitor

- Email delivery success rate
- Average response time
- API error rates by status code
- Daily/monthly email volume
- Retry rates and reasons

## Error Handling

### Automatic Retry Logic

The production configuration includes:
- **5 retries** (vs 3 in development)
- **45-second timeout** (vs 30 in development)
- Exponential backoff for transient errors
- Circuit breaker pattern for persistent failures

### Error Categories

| HTTP Status | Error Type | Action |
|-------------|------------|---------|
| 400 | Invalid Request | Log error, don't retry |
| 401 | Authentication | Disable service immediately |
| 403 | Forbidden | Check permissions, retry later |
| 429 | Rate Limited | Retry with backoff |
| 5xx | Server Error | Retry with exponential backoff |

## Fallback Options

### Automatic Fallback

When Resend service is unavailable:
1. Service switches to Supabase email service
2. Errors logged for monitoring
3. Users notified of delivery attempts

### Configuration

```bash
EMAIL_FALLBACK_ENABLED=true
EMAIL_SERVICE_SELECTOR=enabled
```

## Performance Optimization

### Production Settings

- **Connection Pooling**: Maximum 10 connections
- **Keep-Alive**: Enabled for efficiency
- **Compression**: Gzip enabled (`Accept-Encoding: gzip`)
- **Caching**: Disabled for email requests (`Cache-Control: no-cache`)

### Load Balancing

For high-volume applications:
- Distribute requests across multiple API keys
- Implement regional load balancing
- Monitor per-key usage limits

## Compliance and Security

### GDPR Compliance

- User consent for marketing emails
- Data retention policies
- Right to deletion support

### Security Best Practices

- Use HTTPS only (`RESEND_ENABLE_SSL=true`)
- Rotate API keys regularly
- Monitor for unauthorized access
- Implement rate limiting on your side

### Data Protection

- No sensitive user data in email logs
- Sanitize email content before logging
- Use request IDs for tracking without PII

## Troubleshooting

### Common Issues

#### 1. Authentication Failed (401)

```bash
# Check API key validity
curl -H "Authorization: Bearer YOUR_API_KEY" https://api.resend.com/domains
```

#### 2. Domain Verification Failed

- Verify DNS records are live
- Check SPF/DKIM/DMARC configuration
- Wait for DNS propagation (up to 24 hours)

#### 3. Emails Not Delivering

- Check spam folders
- Verify recipient email addresses
- Review sending reputation
- Test with different email providers

#### 4. Rate Limiting

- Check current usage limits
- Implement exponential backoff
- Consider upgrading plan if needed

### Debug Commands

```bash
# Check API health
curl -H "Authorization: Bearer $RESEND_API_KEY" https://api.resend.com/limits

# Test domain status
curl -H "Authorization: Bearer $RESEND_API_KEY" https://api.resend.com/domains

# View recent emails
curl -H "Authorization: Bearer $RESEND_API_KEY" https://api.resend.com/emails?limit=10
```

## Updates and Maintenance

### Regular Tasks

- [ ] Monitor daily email volume and limits
- [ ] Check domain verification status monthly
- [ ] Review error logs weekly
- [ ] Update API keys annually
- [ ] Test backup email service monthly

### Scaling Checklist

As your application grows:
- [ ] Monitor API usage quotas
- [ ] Set up alerts for limits
- [ ] Consider Resend Pro/Business plans
- [ ] Implement email queueing for high volume
- [ ] Set up dedicated IP warming for delivery

## Support and Resources

- **Resend Documentation**: https://resend.com/docs
- **API Reference**: https://resend.com/docs/api-reference
- **Support**: Available through Resend dashboard
- **Status Page**: https://status.resend.com

---

## Quick Setup Script

For automated production setup:

```bash
#!/bin/bash

# Set production environment variables
export RESEND_API_KEY="your_production_api_key"
export RESEND_DOMAIN="yourdomain.com"
export EMAIL_FROM_ADDRESS="noreply@yourdomain.com"
export APP_ENVIRONMENT="production"
export RESEND_TIMEOUT_SECONDS="45"
export RESEND_MAX_RETRIES="5"
export RESEND_ENABLE_SSL="true"

# Verify configuration
echo "Configuration complete!"
echo "API Key: ${RESEND_API_KEY:0:8}..."
echo "Domain: $RESEND_DOMAIN"
echo "Environment: $APP_ENVIRONMENT"
```

This configuration ensures your Resend email service is production-ready with proper security, monitoring, and error handling in place.



