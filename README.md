# 💰 Open-Source Maintainer Streaming Grants

## 🚀 Overview

A Stacks smart contract that enables **continuous micropayments** to open-source maintainers based on real-time usage metrics. No more waiting for grants or donations - get paid as your project gets used! 📈

## ✨ Features

- 🔄 **Streaming Payments**: Continuous block-by-block payments
- 📊 **Usage-Based**: Rewards scale with downloads, stars, and contributors  
- 💎 **Multiplier System**: Higher usage = higher payout multipliers
- 🎯 **Funder Control**: Pause/resume grants anytime
- 👥 **Multi-Project**: Support multiple maintainers and projects
- 🔒 **Secure**: Built-in authorization and fund protection

## 🏗️ How It Works

1. **Maintainers** register their projects with usage metrics
2. **Funders** create streaming grants with STX tokens
3. **Smart Contract** calculates payouts based on:
   - Base rate per block ⏰
   - Usage score multiplier 🎯
   - Available funds 💰

## 🔧 Usage Instructions

### For Maintainers 👨‍💻

#### 1. Register Your Project
```clarity
(contract-call? .open-source-maintainer-streaming-grants register-maintainer "my-awesome-project")
```

#### 2. Update Usage Metrics
```clarity
(contract-call? .open-source-maintainer-streaming-grants update-project-metrics 
  "my-awesome-project" 
  u10000  ;; downloads
  u500    ;; stars  
  u25     ;; contributors
)
```

#### 3. Claim Your Grants
```clarity
(contract-call? .open-source-maintainer-streaming-grants claim-grant u1)
```

### For Funders 💸

#### Create a Streaming Grant
```clarity
(contract-call? .open-source-maintainer-streaming-grants create-streaming-grant
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; maintainer
  "project-name"
  u100      ;; rate per block (µSTX)
  u100000   ;; total amount (µSTX)
)
```

#### Pause/Resume Grants
```clarity
;; Pause
(contract-call? .open-source-maintainer-streaming-grants pause-grant u1)

;; Resume  
(contract-call? .open-source-maintainer-streaming-grants resume-grant u1)
```

## 📖 Read Functions

### Check Maintainer Info
```clarity
(contract-call? .open-source-maintainer-streaming-grants get-maintainer 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### View Grant Details
```clarity
(contract-call? .open-source-maintainer-streaming-grants get-streaming-grant u1)
```

### Calculate Pending Payout
```clarity
(contract-call? .open-source-maintainer-streaming-grants calculate-payout-amount u1)
```

## 🧮 Usage Score Calculation

**Usage Score = Downloads + (Stars × 2) + (Contributors × 5)**

Higher scores = higher payout multipliers! 🎯

## ⚡ Quick Start

1. Deploy the contract to Stacks testnet/mainnet
2. Maintainers register their projects
3. Funders create streaming grants
4. Maintainers update metrics and claim rewards
5. Profit! 💰

## 🔐 Security Features

- Authorization checks on all functions
- Fund protection mechanisms  
- Active/inactive grant states
- Overflow protection on calculations

## 🛠️ Development

Built with Clarinet for the Stacks blockchain. Uses modern Clarity features including `stacks-block-height` for accurate timing.

## 📄 License

MIT License - Build amazing things! 🚀

---

**Happy Coding!** 👨‍💻✨ Support your favorite open-source projects with streaming micropayments!
