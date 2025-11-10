# Hackathon Track Explanations

## 🏆 Track 1: Best use of a Yield Donating Strategy

**Endaoment is built entirely on Octant's YieldDonating Strategy (YDS) framework.**

- **100% Profit Donation**: Uses `YieldDonatingTokenizedStrategy` with zero fees - all yield automatically minted as shares to `AllocationManager` (acting as `dragonRouter`)
- **Real Yield**: Integrates with Aave V3 Pool on mainnet (verified via fork testing) - demonstrates actual yield accrual
- **Innovative Extension**: Extends YDS beyond simple donation to democratic allocation through three-way split (10% whale, 15% retail, 75% students based on weighted voting)

**Why it's "Best Use":** Extends YDS to democratically allocate yield rather than just donating, creating sustainable funding for student research with real-world impact.

---

## 🌱 Track 2: Best public goods projects

**Endaoment transforms speculative yield into sustainable student research funding.**

- **Direct Impact**: 75% of all generated yield funds student research initiatives through democratic voting
- **Sustainable Model**: Continuous yield streams (30-day epochs) create ongoing funding, not one-time donations
- **Transparent & Inclusive**: All operations on-chain, anyone can participate - no barriers to entry
- **Ecosystem Bridge**: Creates "Degens 🤝 Regens" synergy - degens get yield exposure, students get sustainable funding

**Why it's "Best Public Good":** Solves real problem (student research funding), uses sustainable continuous model, ensures democratic allocation, and is fully transparent and inclusive.

---

## 🎨 Track 3: Most creative use of Octant v2 for public goods

**Endaoment is the first project to combine YDS + RegenStaker + EAS attestations for public goods funding.**

- **YDS + RegenStaker Fusion**: Students stake tokens to build voting power, which amplifies their funding allocation - first to combine these Octant components
- **Weighted Voting Formula**: `Weighted Vote = Depositor Vote × (Student Power + Proposal Votes)` - unique democratic allocation mechanism
- **EAS Integration**: First to use Ethereum Attestation Service for voting power boosts (10% per attestation, up to 50% max) - rewards real-world achievements
- **Three-Way Split**: Extends YDS beyond simple donation to democratic allocation (10% whale, 15% retail, 75% students)

**Why it's "Most Creative":** First to combine YDS + RegenStaker + EAS, introduces weighted voting formula, and extends YDS to democratic allocation rather than simple donation.

---

## 💰 Track 4: Best use of Aave v3 (Aave Vaults)

**Endaoment created a custom ERC-4626 compliant Aave Earn Vault and integrated it seamlessly with YDS.**

- **Custom AaveEarnVault**: ERC-4626 compliant vault wrapping Aave V3 Pool - clean abstraction, full yield pass-through, zero fees
- **Real Mainnet Integration**: Uses actual Aave V3 Pool on Ethereum mainnet, tested via fork - verifies real yield generation
- **Seamless YDS Integration**: YDS uses `AaveEarnVault` as yield source - proper `_deployFunds()`, `_freeFunds()`, and `_harvestAndReport()` implementation
- **Best Practices**: Security (SafeERC20), efficiency (minimal gas), interoperability (ERC-4626 standard)

**Why it's "Best Use of Aave v3":** Custom ERC-4626 vault with real mainnet integration, perfect YDS integration, zero fees (100% yield to public goods), and demonstrates best practices.

---

## Summary

Endaoment uniquely fits all four tracks:
1. **YDS Track**: Built entirely on YDS, extends it with democratic allocation
2. **Public Goods Track**: Funds student research, sustainable model, transparent
3. **Creative Track**: First to combine YDS + RegenStaker + EAS for public goods
4. **Aave Track**: Custom ERC-4626 vault, real mainnet integration, best practices
