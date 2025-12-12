# Cost Estimation - Azure Communication Services Reference Architecture

This document provides detailed cost estimates for the ACS reference architecture across different deployment tiers.

## Pricing Model

Azure Communication Services uses a **consumption-based pricing model**. You pay only for what you use.

### ACS Capability Pricing (as of 2024)

| Capability | Unit | Price (USD) | Notes |
|------------|------|-------------|-------|
| **Voice - VoIP** | per minute | $0.004 | VoIP to VoIP |
| **Voice - PSTN Inbound** | per minute | $0.004 - $0.02 | Varies by country |
| **Voice - PSTN Outbound** | per minute | $0.004 - $0.20 | Varies by country |
| **Video** | per participant/min | $0.004 | 720p quality |
| **Chat** | per message | $0.0008 | Per message sent |
| **SMS - US Outbound** | per message | $0.0075 | Varies by country |
| **SMS - US Inbound** | per message | Free | |
| **Email** | per 1000 emails | $0.25 | Includes 100MB attachments |
| **Phone Numbers** | per number/month | $1 - $100 | Toll-free higher |
| **Recording** | per minute | $0.002 | Plus storage costs |

## Deployment Tiers

### 🟢 Development/Test Environment

**Monthly usage assumptions:**

- 1,000 voice minutes (VoIP)
- 500 video minutes (10 participants avg)
- 5,000 chat messages
- 500 SMS messages
- 1,000 emails
- 1 phone number

| Resource | Calculation | Monthly Cost |
|----------|-------------|--------------|
| ACS Voice | 1,000 × $0.004 | $4.00 |
| ACS Video | 500 × 10 × $0.004 | $20.00 |
| ACS Chat | 5,000 × $0.0008 | $4.00 |
| ACS SMS | 500 × $0.0075 | $3.75 |
| ACS Email | 1 × $0.25 | $0.25 |
| Phone Number | 1 × $2 | $2.00 |
| App Service (B1) | 1 × $13.14 | $13.14 |
| Functions (Consumption) | Included | $0.00 |
| Cosmos DB (Serverless) | ~$5 | $5.00 |
| Key Vault | 1,000 ops × $0.03 | $0.03 |
| Log Analytics | 1 GB × $2.76 | $2.76 |
| App Insights | Included 5GB | $0.00 |
| **Total** | | **~$55/month** |

### 🟡 Small Business / Production

**Monthly usage assumptions:**

- 10,000 voice minutes (mix VoIP/PSTN)
- 5,000 video minutes (20 participants avg)
- 50,000 chat messages
- 5,000 SMS messages
- 10,000 emails
- 5 phone numbers

| Resource | Calculation | Monthly Cost |
|----------|-------------|--------------|
| ACS Voice (VoIP) | 5,000 × $0.004 | $20.00 |
| ACS Voice (PSTN) | 5,000 × $0.015 | $75.00 |
| ACS Video | 5,000 × 20 × $0.004 | $400.00 |
| ACS Chat | 50,000 × $0.0008 | $40.00 |
| ACS SMS | 5,000 × $0.0075 | $37.50 |
| ACS Email | 10 × $0.25 | $2.50 |
| Phone Numbers | 5 × $2 | $10.00 |
| Recording Storage | 100 GB × $0.0184 | $1.84 |
| App Service (S1) | 1 × $73 | $73.00 |
| Functions (Consumption) | ~$10 | $10.00 |
| Cosmos DB | 400 RU/s | $23.36 |
| Key Vault | 10,000 ops | $0.30 |
| Log Analytics | 5 GB | $13.80 |
| App Insights | 10 GB | $5.00 |
| **Total** | | **~$700/month** |

### 🔴 Enterprise / High Volume

**Monthly usage assumptions:**

- 100,000 voice minutes
- 50,000 video minutes (50 participants avg)
- 500,000 chat messages
- 50,000 SMS messages
- 100,000 emails
- 20 phone numbers

| Resource | Calculation | Monthly Cost |
|----------|-------------|--------------|
| ACS Voice (VoIP) | 50,000 × $0.004 | $200.00 |
| ACS Voice (PSTN) | 50,000 × $0.015 | $750.00 |
| ACS Video | 50,000 × 50 × $0.004 | $10,000.00 |
| ACS Chat | 500,000 × $0.0008 | $400.00 |
| ACS SMS | 50,000 × $0.0075 | $375.00 |
| ACS Email | 100 × $0.25 | $25.00 |
| Phone Numbers | 20 × $5 (toll-free) | $100.00 |
| Recording Storage | 1 TB × $0.0184 | $18.84 |
| App Service (P1v3) | 2 × $146 | $292.00 |
| Functions (Premium EP1) | 1 × $146 | $146.00 |
| Cosmos DB | 1000 RU/s | $58.40 |
| Key Vault | 100,000 ops | $3.00 |
| Log Analytics | 50 GB | $138.00 |
| App Insights | 50 GB | $115.00 |
| **Total** | | **~$12,600/month** |

## Cost Optimization Strategies

### 1. Reserved Capacity

| Resource | Discount | Commitment |
|----------|----------|------------|
| App Service | 35-55% | 1-3 years |
| Cosmos DB | 20-25% | 1-3 years |
| Virtual Machines | 30-60% | 1-3 years |

### 2. Architecture Optimizations

- **Serverless for low traffic**: Use Cosmos DB serverless for dev/test
- **Connection pooling**: Reduce resource consumption
- **Caching**: Reduce database reads
- **Batch operations**: Reduce transaction overhead

### 3. Monitoring & Budgets

```bash
# Set up cost alerts
az consumption budget create \
    --budget-name acs-monthly-budget \
    --amount 1000 \
    --time-grain Monthly \
    --time-period 2024-01-01/2024-12-31 \
    --resource-group rg-acs-prod
```

## TCO Comparison

### Build vs. Buy Communication Platform

| Factor | Build Custom | Use ACS |
|--------|--------------|---------|
| Initial Development | $200k - $500k | $5k - $20k |
| Time to Market | 6-18 months | 2-4 weeks |
| Maintenance (annual) | $100k - $200k | Included |
| Infrastructure | Self-managed | Managed |
| Compliance | Self-certified | Pre-certified |
| Scalability | Manual | Automatic |
| **5-Year TCO** | **$800k - $1.5M** | **$150k - $400k** |

**Savings: 60-80% with ACS**

## Azure Pricing Calculator

For detailed estimates customized to your usage:

[Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)

Configure:

1. Azure Communication Services
2. App Service
3. Azure Functions
4. Cosmos DB
5. Azure Monitor

## Notes

- Prices are estimates and may vary by region
- Enterprise agreements may include discounts
- Pricing subject to change - verify on Azure.com
- Storage and bandwidth costs may add 5-10%
