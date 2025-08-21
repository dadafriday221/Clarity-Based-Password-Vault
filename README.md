# 🔐 Clarity-Based Password Vault

A secure, blockchain-based password vault smart contract that stores encrypted credential hashes with multi-signature recovery capabilities on the Stacks blockchain.

## ✨ Features

- **🛡️ Secure Storage**: Store encrypted password hashes on-chain
- **🔑 Multi-Sig Recovery**: Recover access with multiple trusted principals
- **🔒 Vault Locking**: Lock vaults to prevent unauthorized access
- **⏱️ Access Tracking**: Track vault creation and last access times
- **👥 Flexible Recovery**: Configurable signature requirements

## 🚀 Quick Start

### Creating a Vault

```clarity
(contract-call? .Clarity-Based-Password-Vault create-vault
  "encrypted-hash-string-here"
  (list 'SP1ABC... 'SP2DEF... 'SP3GHI...)
  u2
)
```

### Accessing Your Vault

```clarity
(contract-call? .Clarity-Based-Password-Vault access-vault u1)
```

### Updating Vault Hash

```clarity
(contract-call? .Clarity-Based-Password-Vault update-vault-hash
  u1
  "new-encrypted-hash-string"
)
```

## 🔄 Recovery Process

### 1. Initiate Recovery
Any recovery principal can initiate recovery:

```clarity
(contract-call? .Clarity-Based-Password-Vault initiate-recovery
  u1
  "new-encrypted-hash-after-recovery"
)
```

### 2. Sign Recovery
Other recovery principals sign the recovery request:

```clarity
(contract-call? .Clarity-Based-Password-Vault sign-recovery u1 u1)
```

### 3. Automatic Completion
Once enough signatures are collected, recovery completes automatically.

## 🔧 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `create-vault` | 📝 Create a new password vault |
| `update-vault-hash` | ✏️ Update encrypted hash (owner only) |
| `access-vault` | 👀 Access vault and get encrypted hash |
| `lock-vault` | 🔒 Lock vault to prevent access |
| `initiate-recovery` | 🚨 Start multi-sig recovery process |
| `sign-recovery` | ✍️ Sign a recovery request |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-vault` | 📋 Get vault information |
| `get-recovery-status` | 📊 Check recovery process status |
| `get-next-vault-id` | 🔢 Get next available vault ID |
| `get-next-recovery-id` | 🔢 Get next available recovery ID |

## 🛠️ Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📚 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Owner only operation |
| `u101` | Vault not found |
| `u102` | Unauthorized access |
| `u103` | Invalid recovery operation |
| `u104` | Resource already exists |
| `u105` | Insufficient signatures |

## 🔒 Security Considerations

- **Encrypt Off-Chain**: Always encrypt passwords client-side before storing hashes
- **Choose Trustees Wisely**: Select recovery principals you trust completely
- **Regular Updates**: Update vault hashes periodically for better security
- **Monitor Access**: Check last access times to detect unauthorized attempts

## 📄 License

This project is licensed under the MIT License.

---

*Built with ❤️ for the Stacks ecosystem*
