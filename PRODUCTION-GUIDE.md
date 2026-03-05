# 🚀 KOPA-MKOPAJI Production STK Push Implementation Guide

## Overview
Your KOPA-MKOPAJI application is now ready for production M-Pesa STK Push integration! This guide will help you deploy to production safely.

## 🔧 What's Been Implemented

### ✅ Production-Ready Features
- **Enhanced M-Pesa Service** with production validation
- **Robust Callback Handling** with proper error management  
- **Smart Payment Monitoring** with activity detection
- **Production Configuration Validation**
- **Comprehensive Logging** for transaction tracking
- **Security Hardening** for production use

### ✅ Error Handling & Monitoring
- Fast initial payment detection (3s)
- Smart interval scheduling (5s fast mode → 8-20s adaptive)
- Activity-based monitoring adjustment
- Rate limit protection with fallback
- Detailed transaction logging
- Production callback validation

## 🎯 Production Setup Steps

### Step 1: Get Production Credentials
1. Go to [Safaricom Daraja Portal](https://developer.safaricom.co.ke/)
2. Create a **Production App** (not sandbox)
3. Get your production credentials:
   - Consumer Key
   - Consumer Secret
   - Business Short Code (your actual Till/Paybill)
   - Production Passkey

### Step 2: Configure Production Environment
```bash
# Create production configuration
cp .env .env.sandbox  # Backup current config
cp .env.production.template .env.production

# Edit .env.production with your real credentials:
MPESA_CONSUMER_KEY=your_real_production_key
MPESA_CONSUMER_SECRET=your_real_production_secret  
MPESA_BUSINESS_SHORTCODE=your_real_till_number
MPESA_PASSKEY=your_real_production_passkey
MPESA_CALLBACK_URL=https://kopa.mkopaji.com/api/mpesa-callback
MPESA_ENVIRONMENT=production
```

### Step 3: Deploy to Production Server
```bash
# Deploy to your production server
scp -r . user@yourserver:/path/to/kopa-mkopaji/

# On production server:
cd /path/to/kopa-mkopaji
npm install
cp .env.production .env
node backend/server.js
```

### Step 4: Test Production Integration
```bash
# Test with small amounts first
curl -X POST https://kopa.mkopaji.com/api/initiate-stk-push \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "254700000000",
    "amount": 1,
    "accountReference": "TEST",
    "transactionDesc": "Test payment"
  }'
```

## 🔐 Security Requirements

### ✅ HTTPS Required
- All callback URLs must use HTTPS in production
- SSL certificate must be valid
- Server must be accessible from internet

### ✅ Environment Variables
- Never commit production credentials to code
- Use environment variables for all sensitive data
- Secure your .env files with proper permissions

### ✅ Callback Validation
```javascript
// Production callbacks include validation
app.post('/api/mpesa-callback', (req, res) => {
  // Validates callback structure
  // Processes payments securely
  // Logs all transactions
});
```

## 📊 Monitoring & Logging

### Transaction Logging
```
📞 M-Pesa Callback received at: 2025-11-10T15:30:00.000Z
📞 ✅ Payment successful!
📞 💰 Receipt Number: ABC123XYZ
📞 📅 Transaction Date: 20251110153000
📞 💵 Confirmed Amount: 150
📞 📱 Confirmed Phone: 254700000000
```

### Status Monitoring
```
[M-Pesa Production] ✅ Access token obtained successfully
[M-Pesa Production] 📅 Token expires in 3599 seconds
[M-Pesa Production] 🚀 Initiating STK Push...
[M-Pesa Production] 📱 Phone: 254700000000
[M-Pesa Production] 💰 Amount: KES 150
```

## 🚨 Production Checklist

### Pre-Launch
- [ ] Production credentials obtained from Safaricom
- [ ] Business short code registered for STK Push
- [ ] Domain configured with valid SSL certificate
- [ ] Server firewall configured (allow HTTPS)
- [ ] Backup systems in place
- [ ] Monitoring tools configured

### Testing Phase  
- [ ] Test with KES 1-10 amounts first
- [ ] Verify callbacks are received correctly
- [ ] Test payment success scenarios
- [ ] Test payment failure scenarios  
- [ ] Test timeout handling
- [ ] Verify transaction logging

### Go-Live
- [ ] Start with limited users
- [ ] Monitor all transactions closely
- [ ] Have support channels ready
- [ ] Document any issues
- [ ] Scale gradually

## 📞 Support & Troubleshooting

### Common Production Issues

**Error 2029: "Invalid Business ShortCode"**
- Verify your business short code is registered for STK Push
- Contact Safaricom to enable STK Push on your account

**Error 2001: "Invalid Phone Number"**
- Ensure phone format: 254XXXXXXXXX
- Test with known active M-Pesa numbers

**Callback Not Received**
- Verify callback URL is accessible via HTTPS
- Check firewall allows incoming connections
- Test callback URL manually

### Safaricom Support
- **Technical Support**: +254 722 000 000
- **Daraja Portal**: https://developer.safaricom.co.ke/
- **Documentation**: https://developer.safaricom.co.ke/docs

## 🎉 Production Ready!

Your FUNDFAST application now includes:
- ✅ **Production M-Pesa Integration**
- ✅ **Enhanced Payment Monitoring** 
- ✅ **Robust Error Handling**
- ✅ **Comprehensive Logging**
- ✅ **Security Hardening**
- ✅ **Callback Validation**

## Quick Commands

```bash
# Switch to production
cp .env.production .env && node backend/server.js

# Switch to sandbox  
cp .env.sandbox .env && node backend/server.js

# View production config
node -e "require('dotenv').config(); console.log('Environment:', process.env.MPESA_ENVIRONMENT)"

# Test production auth
node -e "require('./backend/mpesa-service.js').getAccessToken().then(t => console.log('✅ Auth OK')).catch(e => console.log('❌', e.message))"
```

---
**🔴 Remember: Start with small test amounts in production!**

## 🛡️ Best-Practice Forced Recovery (Independent of GitHub Actions)

When GitHub Actions queue is degraded, deploy directly from the server with the built-in scripts.

### One-command forced deploy (run on your local machine)

```bash
ssh root@kopa.mkopaji.com "cd /var/www/html/kopa-mkopaji && git pull origin main && chmod +x tools/force-server-deploy.sh && sudo APP_DIR=/var/www/html/kopa-mkopaji APP_NAME=kopa-mkopaji SITE_NAME=kopa-mkopaji DOMAIN=kopa.mkopaji.com WWW=www.kopa.mkopaji.com EMAIL=admin@kopa.mkopaji.com bash tools/force-server-deploy.sh"
```

### Install automatic self-heal deploy (every 5 minutes)

Run once on the server:

```bash
cd /var/www/html/kopa-mkopaji
git pull origin main
chmod +x tools/install-auto-recover-cron.sh
sudo APP_DIR=/var/www/html/kopa-mkopaji APP_NAME=kopa-mkopaji SITE_NAME=kopa-mkopaji DOMAIN=kopa.mkopaji.com WWW=www.kopa.mkopaji.com EMAIL=admin@kopa.mkopaji.com BRANCH=main bash tools/install-auto-recover-cron.sh
```

### Verify auto-heal status

```bash
crontab -l | grep auto-recover-deploy
tail -n 100 /var/log/kopa-mkopaji-auto-deploy.log
```