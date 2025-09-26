# Prosora Ghost Blog CMS - Service Integrations Guide

## 📧 Email Service Integration (Resend)

### Overview
Resend provides modern email delivery with excellent deliverability rates and a developer-friendly API.

### Setup Process

#### 1. Create Resend Account
1. Visit [Resend.com](https://resend.com)
2. Sign up for a free account
3. Verify your email address

#### 2. Domain Verification
```bash
# Add these DNS records to your domain:
Type: TXT
Name: @
Value: resend-verify=your_verification_code

Type: MX
Name: @
Value: 10 mx.resend.com

Type: TXT
Name: @
Value: "v=spf1 include:_spf.resend.com ~all"

Type: TXT
Name: resend._domainkey
Value: your_dkim_key
```

#### 3. API Key Generation
1. Go to API Keys section in Resend dashboard
2. Create a new API key with "Sending access"
3. Copy the API key (starts with `re_`)

#### 4. Ghost Configuration
Update your `.env` file:
```bash
RESEND_API_KEY=re_your_api_key_here
MAIL_FROM=noreply@yourdomain.com
MAIL_FROM_NAME=Your Blog Name
```

#### 5. Ghost Admin Configuration
1. Go to Ghost Admin → Settings → Email newsletter
2. Configure sender details:
   - **From address**: `noreply@yourdomain.com`
   - **From name**: `Your Blog Name`
3. Test email delivery

### Advanced Configuration

#### Webhook Setup for Email Events
```bash
# Add webhook endpoint in Resend dashboard
Endpoint URL: https://yourdomain.com/webhooks/resend
Events: delivered, bounced, complained, clicked, opened
```

#### Email Templates
Create custom email templates in Ghost:
1. Go to Settings → Email newsletter
2. Customize newsletter template
3. Set up welcome emails for new subscribers

### Monitoring and Analytics
- Track delivery rates in Resend dashboard
- Monitor bounce and complaint rates
- Set up alerts for delivery issues
- Analyze email performance metrics

---

## 🖼️ Media Storage Integration (Cloudinary)

### Overview
Cloudinary provides cloud-based image and video management with automatic optimization and global CDN delivery.

### Setup Process

#### 1. Create Cloudinary Account
1. Visit [Cloudinary.com](https://cloudinary.com)
2. Sign up for a free account
3. Note your cloud name from the dashboard

#### 2. API Credentials
1. Go to Dashboard → Settings → Security
2. Copy your API credentials:
   - Cloud Name
   - API Key
   - API Secret

#### 3. Environment Configuration
Update your `.env` file:
```bash
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
CLOUDINARY_SECURE=true
```

#### 4. Ghost Storage Adapter
The Docker setup automatically configures Cloudinary as the storage adapter for Ghost.

### Advanced Configuration

#### Image Optimization Settings
```javascript
// Automatic optimizations applied:
{
  quality: "auto:best",
  fetch_format: "auto",
  flags: "progressive",
  crop: "limit",
  width: 2000,
  height: 2000
}
```

#### Upload Presets
Create upload presets in Cloudinary dashboard:
1. Go to Settings → Upload
2. Create preset for blog images:
   - **Folder**: `ghost-blog/images`
   - **Format**: Auto
   - **Quality**: Auto
   - **Transformation**: Limit to 2000px

#### CDN Configuration
- Images automatically served via Cloudinary CDN
- Global edge locations for fast delivery
- Automatic format optimization (WebP, AVIF)
- Responsive image delivery

### Monitoring and Optimization
- Monitor usage in Cloudinary dashboard
- Track transformation credits
- Optimize images for better performance
- Set up usage alerts

---

## 💳 Payment Processing Integration (Stripe)

### Overview
Stripe provides comprehensive payment processing for Ghost's membership and subscription features.

### Setup Process

#### 1. Create Stripe Account
1. Visit [Stripe.com](https://stripe.com)
2. Create an account and complete verification
3. Switch to live mode for production

#### 2. API Keys
1. Go to Developers → API keys
2. Copy your keys:
   - Publishable key (starts with `pk_`)
   - Secret key (starts with `sk_`)

#### 3. Webhook Configuration
1. Go to Developers → Webhooks
2. Add endpoint: `https://yourdomain.com/members/webhooks/stripe/`
3. Select events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `customer.subscription.trial_will_end`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
   - `checkout.session.completed`
4. Copy the webhook signing secret

#### 4. Environment Configuration
Update your `.env` file:
```bash
STRIPE_PUBLISHABLE_KEY=pk_live_your_publishable_key
STRIPE_SECRET_KEY=sk_live_your_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
```

#### 5. Ghost Configuration
1. Go to Ghost Admin → Settings → Membership
2. Enable "Connect to Stripe"
3. Enter your Stripe keys
4. Configure subscription tiers and pricing

### Advanced Configuration

#### Product and Pricing Setup
```bash
# Create products in Stripe dashboard:
1. Monthly Subscription - $5/month
2. Annual Subscription - $50/year (save $10)
3. Premium Tier - $15/month
```

#### Tax Configuration
1. Enable Stripe Tax in dashboard
2. Configure tax rates for your regions
3. Set up automatic tax calculation

#### Payment Methods
Enable additional payment methods:
- Credit/Debit Cards (default)
- Apple Pay
- Google Pay
- Bank transfers (ACH)
- SEPA Direct Debit

### Member Management
- Automatic member creation on successful payment
- Subscription lifecycle management
- Dunning management for failed payments
- Customer portal for self-service

---

## 📊 Analytics Integration (TinyBird)

### Overview
TinyBird provides real-time analytics with SQL-based querying and high-performance data processing.

### Setup Process

#### 1. Create TinyBird Account
1. Visit [TinyBird.co](https://tinybird.co)
2. Sign up for a free account
3. Complete onboarding

#### 2. Data Source Creation
1. Go to Data Sources
2. Create new data source for Ghost analytics
3. Define schema for blog events:
```sql
CREATE TABLE ghost_analytics (
    timestamp DateTime,
    event_type String,
    page_url String,
    user_id String,
    session_id String,
    referrer String,
    user_agent String,
    country String,
    device_type String
) ENGINE = MergeTree()
ORDER BY timestamp
```

#### 3. API Token
1. Go to Tokens section
2. Create API token with write permissions
3. Copy the token

#### 4. Environment Configuration
Update your `.env` file:
```bash
TINYBIRD_API_KEY=your_api_token
TINYBIRD_DATASOURCE=ghost_analytics
TINYBIRD_ENDPOINT=https://api.tinybird.co
```

### Advanced Configuration

#### Custom Analytics Tracking
Add tracking script to Ghost theme:
```javascript
// Add to theme's default.hbs
<script>
function trackEvent(eventType, data) {
    fetch('/api/analytics/track', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            event_type: eventType,
            page_url: window.location.href,
            referrer: document.referrer,
            timestamp: new Date().toISOString(),
            ...data
        })
    });
}

// Track page views
trackEvent('page_view', {
    page_title: document.title
});

// Track scroll depth
let maxScroll = 0;
window.addEventListener('scroll', () => {
    const scrollPercent = Math.round(
        (window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100
    );
    if (scrollPercent > maxScroll) {
        maxScroll = scrollPercent;
        if (maxScroll % 25 === 0) {
            trackEvent('scroll_depth', { depth: maxScroll });
        }
    }
});
</script>
```

#### Dashboard Creation
Create analytics dashboards:
1. **Traffic Overview**: Page views, unique visitors, bounce rate
2. **Content Performance**: Most popular posts, engagement metrics
3. **User Behavior**: Session duration, scroll depth, click tracking
4. **Conversion Funnel**: Visitor to subscriber conversion

#### Real-time Queries
Example queries for common metrics:
```sql
-- Daily page views
SELECT 
    toDate(timestamp) as date,
    count() as page_views
FROM ghost_analytics 
WHERE event_type = 'page_view'
GROUP BY date
ORDER BY date DESC

-- Top performing content
SELECT 
    page_url,
    count() as views,
    uniq(session_id) as unique_visitors
FROM ghost_analytics 
WHERE event_type = 'page_view'
GROUP BY page_url
ORDER BY views DESC
LIMIT 10

-- Real-time visitor count
SELECT count(DISTINCT session_id) as active_visitors
FROM ghost_analytics 
WHERE timestamp > now() - INTERVAL 5 MINUTE
```

---

## 🌐 CDN Integration (Cloudflare)

### Overview
Cloudflare provides global CDN, security, and performance optimization for your Ghost blog.

### Setup Process

#### 1. Create Cloudflare Account
1. Visit [Cloudflare.com](https://cloudflare.com)
2. Sign up for a free account
3. Add your domain

#### 2. DNS Configuration
1. Update nameservers at your domain registrar
2. Configure DNS records:
```bash
Type: A
Name: @
Value: YOUR_SERVER_IP
Proxy: Enabled (orange cloud)

Type: A  
Name: www
Value: YOUR_SERVER_IP
Proxy: Enabled (orange cloud)

Type: CNAME
Name: *
Value: yourdomain.com
Proxy: Enabled (orange cloud)
```

#### 3. SSL/TLS Configuration
1. Go to SSL/TLS → Overview
2. Set encryption mode to "Full (strict)"
3. Enable "Always Use HTTPS"
4. Configure HSTS settings

#### 4. Performance Optimization
1. Go to Speed → Optimization
2. Enable Auto Minify (CSS, JavaScript, HTML)
3. Enable Brotli compression
4. Configure caching rules

### Advanced Configuration

#### Page Rules
Create page rules for optimal caching:
```bash
# Static assets - Cache everything
Pattern: yourdomain.com/assets/*
Settings: Cache Level = Cache Everything, Edge Cache TTL = 1 month

# Ghost admin - Bypass cache
Pattern: yourdomain.com/ghost/*
Settings: Cache Level = Bypass

# API endpoints - Bypass cache
Pattern: yourdomain.com/ghost/api/*
Settings: Cache Level = Bypass

# Blog posts - Cache with short TTL
Pattern: yourdomain.com/*
Settings: Cache Level = Standard, Edge Cache TTL = 2 hours
```

#### Security Configuration
1. **Firewall Rules**: Block malicious traffic
2. **Rate Limiting**: Prevent abuse
3. **Bot Fight Mode**: Block bad bots
4. **DDoS Protection**: Automatic protection

#### Performance Features
- **Argo Smart Routing**: Optimize routing
- **Polish**: Image optimization
- **Mirage**: Mobile optimization
- **Rocket Loader**: JavaScript optimization

---

## 🔧 Additional Integrations

### GitHub Integration

#### Repository Setup
1. Create GitHub repository for your Ghost theme
2. Set up GitHub Actions for automated deployment
3. Configure webhooks for theme updates

#### Automated Deployment
```yaml
# .github/workflows/deploy-theme.yml
name: Deploy Ghost Theme
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to Ghost
        run: |
          # Deploy theme to Ghost instance
          curl -X POST "https://yourdomain.com/ghost/api/admin/themes/upload/" \
            -H "Authorization: Ghost ${{ secrets.GHOST_ADMIN_API_KEY }}" \
            -F "file=@theme.zip"
```

### Social Media Integration

#### Twitter/X Integration
```javascript
// Add to Ghost theme
<script>
// Auto-tweet new posts
function shareOnTwitter(title, url) {
    const tweetText = encodeURIComponent(`${title} ${url}`);
    window.open(`https://twitter.com/intent/tweet?text=${tweetText}`);
}
</script>
```

#### Facebook Integration
```html
<!-- Add Facebook SDK -->
<div id="fb-root"></div>
<script async defer crossorigin="anonymous" 
        src="https://connect.facebook.net/en_US/sdk.js#xfbml=1&version=v18.0">
</script>

<!-- Facebook share button -->
<div class="fb-share-button" 
     data-href="{{url absolute="true"}}" 
     data-layout="button_count">
</div>
```

### Search Integration

#### Algolia Search
1. Create Algolia account
2. Configure search index
3. Add search widget to Ghost theme
4. Set up automatic content indexing

### Newsletter Integration

#### Mailchimp Integration
1. Create Mailchimp account
2. Set up audience
3. Configure Ghost webhook to sync subscribers
4. Create automated email campaigns

### Monitoring Integration

#### Uptime Monitoring
1. **UptimeRobot**: Free uptime monitoring
2. **Pingdom**: Advanced monitoring features
3. **StatusPage**: Public status page

#### Error Tracking
1. **Sentry**: Error tracking and performance monitoring
2. **LogRocket**: Session replay and debugging
3. **Rollbar**: Real-time error tracking

---

## 🔍 Integration Testing

### Testing Checklist

#### Email Integration (Resend)
- [ ] Domain verification complete
- [ ] Test email delivery
- [ ] Newsletter signup working
- [ ] Welcome emails sent
- [ ] Bounce handling configured

#### Media Integration (Cloudinary)
- [ ] Image uploads working
- [ ] Automatic optimization enabled
- [ ] CDN delivery functional
- [ ] Responsive images working

#### Payment Integration (Stripe)
- [ ] Test subscription creation
- [ ] Webhook endpoints responding
- [ ] Member access control working
- [ ] Payment failure handling

#### Analytics Integration (TinyBird)
- [ ] Event tracking functional
- [ ] Data ingestion working
- [ ] Queries returning results
- [ ] Dashboard displaying metrics

#### CDN Integration (Cloudflare)
- [ ] DNS resolution correct
- [ ] SSL certificate valid
- [ ] Caching rules applied
- [ ] Performance improvements visible

### Troubleshooting Common Issues

#### Email Delivery Issues
```bash
# Check DNS records
dig TXT yourdomain.com
dig MX yourdomain.com

# Test SMTP connection
telnet smtp.resend.com 587

# Check Ghost email logs
docker logs prosora-ghost | grep -i email
```

#### Image Upload Issues
```bash
# Check Cloudinary credentials
curl -X GET "https://api.cloudinary.com/v1_1/YOUR_CLOUD_NAME/usage" \
  -u "YOUR_API_KEY:YOUR_API_SECRET"

# Test image upload
curl -X POST "https://api.cloudinary.com/v1_1/YOUR_CLOUD_NAME/image/upload" \
  -F "file=@test-image.jpg" \
  -F "upload_preset=YOUR_PRESET"
```

#### Payment Processing Issues
```bash
# Test webhook endpoint
curl -X POST "https://yourdomain.com/members/webhooks/stripe/" \
  -H "Content-Type: application/json" \
  -d '{"type": "customer.subscription.created"}'

# Check Stripe logs in dashboard
# Verify webhook signing secret
```

---

## 📈 Integration Optimization

### Performance Optimization
1. **Lazy Loading**: Implement lazy loading for images
2. **Caching**: Optimize caching strategies
3. **Compression**: Enable compression for all assets
4. **Minification**: Minify CSS and JavaScript

### Cost Optimization
1. **Monitor Usage**: Track service usage regularly
2. **Optimize Images**: Use appropriate image sizes
3. **Cache Effectively**: Reduce API calls with caching
4. **Review Plans**: Regularly review and optimize service plans

### Security Optimization
1. **API Key Rotation**: Regularly rotate API keys
2. **Access Control**: Implement proper access controls
3. **Monitoring**: Monitor for suspicious activity
4. **Updates**: Keep all integrations updated

---

This comprehensive integration guide ensures all external services work seamlessly with your Prosora Ghost Blog CMS, providing a complete Ghost Pro alternative experience.