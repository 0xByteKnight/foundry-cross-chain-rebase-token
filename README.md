# 🌐 Foundry Cross-Chain Rebase Token

![License](https://img.shields.io/badge/license-MIT-green)
![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.24-blue)
![Foundry](https://img.shields.io/badge/Built%20With-Foundry-orange)

## 📌 Overview

**Foundry Cross-Chain Rebase Token** is a decentralized application (dApp) that enables users to deposit ETH in exchange for rebase tokens, which accrue rewards over time. This project leverages Chainlink's Cross-Chain Interoperability Protocol (CCIP) to facilitate seamless token transfers across multiple blockchain networks, ensuring consistent token behavior and supply adjustments irrespective of the chain.

This repository contains the smart contracts, deployment scripts, and testing suite for the Cross-Chain Rebase Token system.

---

## ⚙️ Features

✔️ **Cross-Chain Interoperability** – Utilize Chainlink's CCIP to enable seamless token transfers across supported blockchain networks.  
✔️ **Rebase Mechanism** – Automatically adjust token supply based on predefined parameters to maintain price stability.  
✔️ **Decentralized Deposits** – Users can deposit ETH to mint rebase tokens without intermediaries.  
✔️ **Reward Accrual** – Token holders accrue rewards over time through the rebase mechanism.  
✔️ **Secure and Transparent** – All operations are governed by audited smart contracts, ensuring trustless interactions.

---

## 🏗 Smart Contract Architecture

The system comprises the following core contracts:

### 🔹 [`RebaseToken.sol`](src/RebaseToken.sol)

- Implements the ERC20 interface with an automated rebase mechanism.
- Adjusts token supply based on market conditions to maintain stability.

### 🔹 [`Vault.sol`](src/Vault.sol)

- Manages user deposits and mints corresponding rebase tokens.
- Handles the accrual and distribution of rewards to token holders.

### 🔹 [`RebasePwjTokenPool.sol`](src/RebasePwjTokenPool.sol)

- Integrates with Chainlink's CCIP to facilitate cross-chain token transfers.
- Supports locking and burning tokens on the source chain while releasing and minting on the destination chain.
- Ensures accurate yield calculations by encoding and decoding user interest rates.

---

## 🚀 Installation & Setup

Ensure you have **Foundry** installed. If not, install it using:

```sh
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 1️⃣ Clone the repository:

```sh
git clone https://github.com/0xByteKnight/foundry-cross-chain-rebase-token.git
cd foundry-cross-chain-rebase-token
```

### 2️⃣ Install dependencies:

```sh
forge install
```

### 3️⃣ Compile contracts:

```sh
forge build
```

### 4️⃣ Run tests:

```sh
forge test
```

---

## 📜 Usage

### 💰 Depositing ETH and Minting Rebase Tokens

Users can deposit ETH into the `Vault` contract to mint rebase tokens.

```solidity
vault.deposit{value: 1 ether}();
```

### 🔄 Redeeming Rebase Tokens for ETH

To redeem ETH, users can burn their rebase tokens.

```solidity
vault.redeem(rebaseTokenAmount);
```

### 🌉 Bridging Tokens Cross-Chain

The `RebasePwjTokenPool` contract enables cross-chain token transfers using Chainlink CCIP.

#### 🔒 Locking or Burning Tokens for Transfer
```solidity
Pool.LockOrBurnInV1 memory lockOrBurnIn = Pool.LockOrBurnInV1({
    originalSender: msg.sender,
    amount: 1000 * 1e18,
    remoteChainSelector: destinationChainId
});
RebasePwjTokenPool.lockOrBurn(lockOrBurnIn);
```

#### 🔓 Releasing or Minting Tokens on the Destination Chain
```solidity
Pool.ReleaseOrMintInV1 memory releaseOrMintIn = Pool.ReleaseOrMintInV1({
    receiver: msg.sender,
    amount: 1000 * 1e18,
    sourcePoolData: encodedInterestRate
});
RebasePwjTokenPool.releaseOrMint(releaseOrMintIn);
```

---

## 🏗 Development & Contribution

💡 Found a bug? Have an idea to enhance the platform? Contributions are welcome!

### ✅ Steps to Contribute:

1. **Fork** this repository.
2. **Create** a new branch: `git checkout -b feature-xyz`.
3. **Commit** your changes: `git commit -m "Add feature xyz"`.
4. **Push** to your fork and create a **Pull Request**.

---

## 🔐 Security Considerations

- **Reentrancy Protection** – Ensure that deposit and redemption functions are safeguarded against reentrancy attacks.
- **Accurate Rebase Calculations** – Implement precise algorithms to adjust token supply without causing imbalances.
- **Cross-Chain Consistency** – Verify that token balances and supply are accurately reflected across all supported chains.

---

## 📜 License

This project is licensed under the **MIT License** – feel free to use and modify it.

---

## 🔗 Connect with Me

💼 **GitHub**: [0xByteKnight](https://github.com/0xByteKnight)  
🐦 **Twitter/X**: [@0xByteKnight](https://twitter.com/0xByteKnight)