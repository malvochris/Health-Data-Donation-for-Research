# 🏥 Health Data Donation for Research (DONOR)

A decentralized protocol built on Stacks that enables individuals to donate their anonymized health data to verified researchers in exchange for tokenized rewards.

## 🎯 Overview

The DONOR protocol creates a secure, transparent marketplace for health data sharing where:
- 👤 **Individuals** can donate anonymized health data and earn STX rewards
- 🔬 **Researchers** can access valuable health datasets for their studies
- 🔒 **Privacy** is maintained through anonymization and access controls
- 💰 **Incentives** align all participants in the ecosystem

## ✨ Features

- 📝 **Donor Registration**: Simple registration process for data contributors
- 🏛️ **Researcher Verification**: Stake-based verification system for institutional researchers
- 💾 **Data Donation**: Secure submission of anonymized health data with hash verification
- 🎁 **Token Rewards**: Automatic STX rewards for valid data contributions
- 🔐 **Access Control**: Permission-based data access with expiration
- 🚀 **Off-chain Permits**: Gasless delegated consent via cryptographic signatures
- 📊 **Analytics**: Comprehensive stats tracking for all participants

## 🚀 Getting Started

### For Donors

1. **Register as Donor**
   ```clarity
   (contract-call? .donor register-as-donor)
   ```

2. **Donate Health Data**
   ```clarity
   (contract-call? .donor donate-health-data 
     0x1234567890abcdef... ;; data hash
     "blood-test"         ;; data type
     true)                ;; anonymous flag
   ```

3. **Check Your Stats**
   ```clarity
   (contract-call? .donor get-donor-stats tx-sender)
   ```

### For Researchers

1. **Register and Stake**
   ```clarity
   (contract-call? .donor register-as-researcher 
     "University Hospital"  ;; institution
     "cardiology")         ;; research field
   ```

2. **Request Data Access** (after verification)
   ```clarity
   (contract-call? .donor request-data-access 
     u1                    ;; donation ID
     "cardiac study 2024") ;; purpose
   ```

3. **Access Data**
   ```clarity
   (contract-call? .donor access-data u1) ;; returns data hash
   ```

### For Off-chain Permits 🚀

1. **Generate Permit Message** (donor signs off-chain)
   ```clarity
   (contract-call? .donor build-permit-message 
     u1                        ;; donation ID
     'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; researcher
     u150000                   ;; expiry block
     tx-sender)                ;; donor address
   ```

2. **Redeem Permit** (anyone can call)
   ```clarity
   (contract-call? .donor redeem-permit
     u1                        ;; donation ID
     'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; researcher
     u150000                   ;; expiry block
     u0                        ;; nonce
     { r: 0x..., s: 0x... }    ;; signature
     0x...                     ;; donor public key
     'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE) ;; donor address
   ```

## 💰 Economics

- **Donor Reward**: 1 STX per data donation
- **Researcher Stake**: 5 STX minimum stake required
- **Data Expiry**: 144,000 blocks (~1 year)
- **Access Tracking**: Full audit trail of data usage

## 🛡️ Security Features

- ✅ **Verification Required**: Only verified researchers can access data
- ⏰ **Time-Limited Access**: Data expires after set block height
- 🔒 **Permission System**: Explicit access requests required
- 💼 **Stake Mechanism**: Economic incentives for proper behavior
- 📝 **Audit Trail**: Complete history of all data access

## 📋 Contract Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|---------|
| `register-as-donor` | Register to donate data | Anyone |
| `register-as-researcher` | Register as researcher with stake | Anyone |
| `verify-researcher` | Verify researcher account | Owner only |
| `donate-health-data` | Submit anonymized health data | Donors |
| `request-data-access` | Request access to specific data | Verified researchers |
| `access-data` | Retrieve data hash | Authorized researchers |
| `fund-contract` | Add funds for rewards | Anyone |
| `withdraw-excess-funds` | Withdraw surplus funds | Owner only |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-donor-info` | Get donor registration details |
| `get-researcher-info` | Get researcher details |
| `get-donation-info` | Get data donation details |
| `get-contract-stats` | Get overall platform statistics |
| `can-access-data` | Check if researcher can access data |
| `get-donor-stats` | Get donor participation stats |
| `get-researcher-stats` | Get researcher activity stats |

## 🏗️ Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Testing
```bash
clarinet check
clarinet test
```

### Deployment
```bash
clarinet deploy --testnet
```

## 📊 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `ERR-NOT-AUTHORIZED` | Insufficient permissions |
| u101 | `ERR-ALREADY-EXISTS` | Entity already registered |
| u102 | `ERR-NOT-FOUND` | Entity not found |
| u103 | `ERR-INSUFFICIENT-FUNDS` | Insufficient STX balance |
| u104 | `ERR-INVALID-DATA` | Invalid data submitted |
| u105 | `ERR-ACCESS-DENIED` | Data access not permitted |
| u106 | `ERR-EXPIRED` | Data has expired |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📜 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)

---

Made with ❤️ for advancing medical research through decentralized data sharing

## 🎁 Off-chain Permit System

The permit system allows donors to grant data access through cryptographic signatures without on-chain transactions, enabling gasless consent workflows.

### How It Works

1. **Donor signs off-chain**: Generate a permit message and sign with private key
2. **Anyone can redeem**: Submit the signature on-chain to grant access
3. **One-time use**: Each permit can only be redeemed once using nonces
4. **Time-bound**: Permits expire at specified block heights

### Permit Functions

- `redeem-permit`: Redeem signed permit to grant researcher access
- `grant-permit-access`: Direct permit grant by donor (on-chain)
- `build-permit-message`: Get message hash for off-chain signing
- `get-permit-nonce`: Get current nonce for donor
- `is-permit-used`: Check permit redemption status

### Permit Error Codes

- `u200`: Invalid cryptographic signature
- `u201`: Permit expired
- `u202`: Permit already used
- `u203`: Donor not registered
- `u204`: Invalid nonce or unauthorized
