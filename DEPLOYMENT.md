# Ghost Pro 6 Blog CMS - Deployment Guide

This guide covers deploying Ghost Pro 6 with PostgreSQL (Neon), Cloudinary storage, and Mailgun email integration on Render.

## 🚀 Quick Deploy to Render

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

## 📋 Required Environment Variables

Set these environment variables in your Render dashboard:

#### Database (Neon PostgreSQL)
```
DATABASE_URL=your-neon-postgresql-connection-string
```

#### Cloudinary Storage
```
CLOUDINARY_CLOUD_NAME=your-cloudinary-cloud-name
CLOUDINARY_API_KEY=your-cloudinary-api-key
CLOUDINARY_API_SECRET=your-cloudinary-api-secret
```

#### Mailgun Email
```
MAILGUN_API_KEY=your-mailgun-api-key
MAILGUN_DOMAIN=your-mailgun-domain
MAILGUN_SMTP_USER=your-mailgun-smtp-user
MAILGUN_SMTP_PASS=your-mailgun-smtp-password
GHOST_FROM_EMAIL=noreply@your-domain.com
```

#### Analytics & Payments (Optional)
```
TINYBIRD_API_KEY=your-tinybird-api-key
STRIPE_PUBLISHABLE_KEY=pk_test_your-stripe-publishable-key
STRIPE_SECRET_KEY=sk_test_your-stripe-secret-key
STRIPE_WEBHOOK_SECRET=whsec_your-stripe-webhook-secret
```

## 🔧 Setup Instructions

### 1. Database Setup (Neon)
1. Create account at [Neon](https://neon.tech)
2. Create new PostgreSQL database
3. Copy connection string to `DATABASE_URL`

### 2. Storage Setup (Cloudinary)
1. Create account at [Cloudinary](https://cloudinary.com)
2. Get API credentials from dashboard
3. Set `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`

### 3. Email Setup (Mailgun)
1. Create account at [Mailgun](https://mailgun.com)
2. Verify your domain or use sandbox domain
3. Get SMTP credentials and API key
4. Set `MAILGUN_API_KEY`, `MAILGUN_DOMAIN`, `MAILGUN_SMTP_USER`, `MAILGUN_SMTP_PASS`

### 4. Deploy to Render
1. Fork this repository
2. Connect to Render
3. Set environment variables in Render dashboard
4. Deploy!

## 🔒 Security Features

- ✅ No hardcoded credentials in repository
- ✅ Environment variables managed by Render
- ✅ GitHub Push Protection compliant
- ✅ SSL/TLS encryption for all connections
- ✅ Secure database connections with SSL

## 📚 Additional Resources

- [Ghost Documentation](https://ghost.org/docs/)
- [Neon Documentation](https://neon.tech/docs)
- [Cloudinary Documentation](https://cloudinary.com/documentation)
- [Mailgun Documentation](https://documentation.mailgun.com/)
- [Render Documentation](https://render.com/docs)

## 🆘 Support

If you encounter issues:
1. Check Render logs for errors
2. Verify all environment variables are set
3. Ensure database connection is working
4. Check Cloudinary and Mailgun configurations

## 📝 License

This project is licensed under the MIT License.