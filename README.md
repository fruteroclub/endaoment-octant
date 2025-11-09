# Endaoment: Bridging Degens 🤝 Regens Through Yield-Powered Student Funding

> **A regenerative public goods protocol that transforms speculative yield into sustainable student research funding, embodying the Degen 🤝 Regen synergy.**

## 🌱 What is Endaoment?

**Endaoment** is a decentralized protocol that enables anyone to support student research initiatives while earning yield exposure. It combines:

- **YieldDonating Strategies (YDS)** from Octant - generating yield from DeFi protocols like Aave
- **RegenStaker** - representing student voting power through staking
- **AllocationManager** - democratically distributing yield based on weighted votes

### The Problem We Solve

Traditional funding models for students and public goods face critical challenges:
- **Limited scalability**: Traditional grants can't scale with demand
- **Coordination failures**: Donors and beneficiaries struggle to align incentives
- **Speculative waste**: Degen energy generates yield but lacks purpose
- **Slow execution**: Regen projects move too slowly to capture momentum

### Our Solution: The Regenerative Flywheel

Endaoment creates a **self-sustaining system** where:

1. **Degens** deposit assets → Generate yield through Aave/DeFi protocols 🚀
2. **Yield is donated** → 100% of profits go to public goods (no fees) 💰
3. **Students stake** → Build voting power through RegenStaker 🍄
4. **Weighted voting** → Depositors + students vote on funding allocation 🗳️
5. **Yield distribution** → 10% whale / 15% retail / 75% students (weighted by votes) 📊
6. **Sustainable funding** → Students receive continuous support for research 🌱

**Result**: Speculative energy (Degen) fuels regenerative impact (Regen) → **1 + 1 = 3** ⚡

---

## 🎩🤝🍄 The Degen 🤝 Regen Connection

Endaoment embodies the **Degens 🤝 Regens Manifesto** by creating a bridge between two complementary forces:

### How Degens Benefit
- ✅ **Yield exposure** without fees - deposit assets, earn yield, support public goods
- ✅ **Viral coordination** - participate in funding decisions through voting
- ✅ **Purpose-driven speculation** - your yield directly funds student research
- ✅ **Transparent impact** - see exactly how your deposits create value

### How Regens Benefit
- ✅ **Sustainable funding** - continuous yield streams replace one-time grants
- ✅ **Democratized allocation** - students and depositors vote together
- ✅ **Scalable infrastructure** - protocol handles distribution automatically
- ✅ **Aligned incentives** - students with more staking power get more funding

### The Synergy
When **Degens and Regens collaborate** in Endaoment:
- **Degen energy** (liquidity + yield) → **Regen structure** (student funding) → **Exponential impact** 🚀🌱⚡

This is **not zero-sum**—it's about multiplying value through coordination.

---

## 🔄 How It Works

### Complete Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     ENDAOMENT PROTOCOL FLOW                      │
└─────────────────────────────────────────────────────────────────┘

1. DEPOSIT PHASE
   ┌──────────┐      ┌──────────────┐      ┌─────────────┐
   │  Degens  │─────▶│  YDS Vault   │─────▶│ Aave Pool   │
   │ (Whale/  │      │ (ERC-4626)   │      │ (Yield Gen) │
   │  Retail) │      │              │      │             │
   └──────────┘      └──────────────┘      └─────────────┘
                            │
                            │ (yield generated)
                            ▼
                    ┌──────────────┐
                    │ AllocationMgr │
                    │ (dragonRouter)│
                    └──────────────┘

2. STUDENT PHASE
   ┌──────────┐      ┌──────────────┐      ┌─────────────┐
   │ Students │─────▶│ RegenStaker  │─────▶│ StudentVoting│
   │  Stake   │      │ (Earning Pwr)│      │ (Proposals) │
   └──────────┘      └──────────────┘      └─────────────┘

3. VOTING PHASE
   ┌──────────────┐      ┌──────────────┐
   │ Depositors   │─────▶│ AllocationMgr│
   │ Allocate     │      │ (Weighted    │
   │ Votes        │      │  Votes)      │
   └──────────────┘      └──────────────┘
         │                      │
         │                      │
         └──────────┬───────────┘
                    │
                    ▼
            ┌──────────────┐
            │ Weighted Vote│
            │ Calculation  │
            │ = Depositor  │
            │   Vote ×     │
            │   (Student   │
            │   Power +    │
            │   Proposal   │
            │   Votes)     │
            └──────────────┘

4. DISTRIBUTION PHASE
   ┌──────────────┐
   │ AllocationMgr│
   │ Redeems      │
   │ Shares       │
   └──────────────┘
         │
         ├─── 10% ──▶ Whale (vault creator)
         ├─── 15% ──▶ Retail (proportional to shares)
         └─── 75% ──▶ Students (proportional to weighted votes)
```

### Key Components

1. **YieldDonating Strategy (YDS)**
   - ERC-4626 compliant vault
   - Deploys assets to Aave V3 Pool
   - Detects profit and mints shares to `AllocationManager`
   - **Zero fees** - all yield donated

2. **RegenStaker** (from octant-v2-core)
   - Students stake ENDAO tokens to build earning power
   - Earning power = voting power for proposals
   - Represents student commitment and engagement
   - Full rewards distribution system for student incentives
   - Open staking (AccessMode.NONE) - permissionless participation

3. **StudentVoting**
   - Students vote for proposals (other students)
   - Uses earning power from RegenStaker
   - Tracks votes per epoch

4. **AllocationManager**
   - Manages 30-day epochs
   - Collects YDS profit shares
   - Calculates weighted votes (depositor + student power)
   - Distributes yield: 10% whale / 15% retail / 75% students

5. **StudentRegistry**
   - Manages verified student profiles
   - Tracks funding received
   - Ensures only active students can participate

---

## 💎 Value Proposition

### For Depositors (Degens)
- **Yield exposure** with zero fees
- **Impact transparency** - see exactly where your yield goes
- **Voting power** - influence funding allocation
- **Public goods contribution** - 100% of profits fund students

### For Students (Regens)
- **Sustainable funding** - continuous yield streams
- **Democratized access** - vote for proposals, receive funding
- **Staking rewards** - more staking = more voting power = more funding
- **Transparent allocation** - weighted voting ensures fair distribution

### For the Ecosystem
- **Regenerative flywheel** - speculative energy → sustainable funding
- **Scalable infrastructure** - protocol handles distribution automatically
- **Aligned incentives** - everyone benefits from protocol success
- **Public good** - anyone can participate, no barriers to entry

---

## 🏗️ Technical Architecture

### Contracts

```
src/
├── strategies/
│   └── yieldDonating/
│       └── YieldDonatingStrategy.sol    # YDS vault (Aave integration)
├── contracts/
│   ├── AllocationManager.sol            # Yield distribution & epochs
│   ├── StudentVoting.sol                 # Student proposal voting
│   └── StudentRegistry.sol               # Student profile management
├── interfaces/
│   ├── IRegenStaker.sol                  # RegenStaker interface
│   └── IStudentRegistry.sol              # StudentRegistry interface
├── tokens/
│   └── EndaomentToken.sol                # ENDAO token (ERC20Permit) for staking
└── test/
    ├── integration/
    │   └── RegenStakerYDSIntegration.t.sol  # Full integration tests
    └── helpers/
        └── RegenStakerSetup.sol             # RegenStaker deployment helper
```

### Integration Points

- **Octant YDS**: Uses `YieldDonatingTokenizedStrategy` for profit donation
- **Aave V3**: Real mainnet integration via fork testing
  - **Aave Earn Vault (ERC-4626)**: YDS uses vault as yield source - see [Vault Integration](./docs/vault-integration-summary.md)
  - Vault wraps Aave Pool for standardized interface and simplified accounting
- **RegenStaker** (octant-v2-core): Real implementation for student voting power
  - Students stake ENDAO tokens to build earning power
  - Full rewards distribution system
  - Open staking (permissionless)
  - Integrated via `RegenStakerWithoutDelegateSurrogateVotes`
- **ERC-4626**: Standard vault interface for deposits/withdrawals

---

## 🎯 How to Demonstrate Endaoment (For Hackathon Judges)

### Quick Demo Script

```bash
# 1. Set up environment
cp .env.example .env
# Add your ETH_RPC_URL and configure TEST_ASSET_ADDRESS, TEST_YIELD_SOURCE

# 2. Install dependencies
forge install
forge soldeer install

# 3. Run Aave Vault tests (visual output showing protocol benefits)
forge test --match-test test_completeFlow \
  --fork-url $ETH_RPC_URL \
  --fork-block-number 20000000 \
  -vvv

# 4. Run full integration tests (complete Endaoment flow)
forge test --match-contract RegenStakerYDSIntegrationTest \
  --fork-url $ETH_RPC_URL \
  --fork-block-number 20000000 \
  -vvv
```

> **💡 Tip**: The Aave Vault tests include **visual CLI output** that clearly shows each step and protocol benefits. Perfect for hackathon demos! See [Aave Vault Testing Guide](./docs/aave-vault-testing.md) for details.

### What the Tests Demonstrate

The integration tests (`RegenStakerYDSIntegration.t.sol`) showcase:

1. **Complete Flow** (`test_completeIntegrationFlow`)
   - ✅ Deposits generate yield through Aave
   - ✅ Profit shares minted to AllocationManager
   - ✅ Weighted voting combines depositor + student power
   - ✅ Yield distributed: 10% whale / 15% retail / 75% students
   - ✅ Student funding recorded in registry

2. **Weighted Voting** (`test_weightedVoteCalculation`)
   - ✅ Students with earning power get amplified votes
   - ✅ Fair distribution based on engagement

3. **Student Power Impact** (`test_studentVotingPowerAffectsAllocation`)
   - ✅ Higher staking power = more funding
   - ✅ Incentivizes student participation

4. **Epoch Management** (`test_epochManagement`)
   - ✅ 30-day epochs with automatic transitions
   - ✅ Synchronized voting and distribution

5. **Security** (`test_shareRedemptionPreventsDoubleRedemption`)
   - ✅ Prevents double redemption attacks
   - ✅ Safe share management

### Key Metrics to Highlight

- **Zero fees**: 100% of yield donated (no performance fees)
- **Real yield**: Generated from Aave V3 on mainnet fork
- **Weighted democracy**: Depositor votes × student power
- **Fair distribution**: 75% to students, 15% to retail, 10% to whale
- **Scalable**: Protocol handles distribution automatically

### Demo Narrative

1. **"Degens deposit"** → Show whale/retail deposits to YDS vault
2. **"Yield generates"** → Demonstrate Aave yield generation (skip 30 days)
3. **"Students stake"** → Show students staking ENDAO tokens in RegenStaker to build earning power
4. **"Voting happens"** → Show depositor + student votes
5. **"Yield distributes"** → Show 10/15/75 split to recipients
6. **"Impact recorded"** → Show student funding in registry

**Key Point**: "This is the Degen 🤝 Regen synergy in action - speculative yield becomes sustainable student funding."

---

## 🧪 Testing & Verification

### Running Tests

```bash
# All integration tests
make test

# Specific test suite
forge test --match-contract RegenStakerYDSIntegrationTest \
  --fork-url $(grep '^ETH_RPC_URL=' .env | cut -d '=' -f2-) \
  --fork-block-number 20000000

# With verbose output
forge test --match-contract RegenStakerYDSIntegrationTest -vvv
```

### Test Coverage

- ✅ Complete integration flow (deposit → yield → distribution)
- ✅ Weighted vote calculation
- ✅ Student power affects allocation
- ✅ Epoch management
- ✅ Share redemption protection
- ✅ Real Aave yield generation (mainnet fork)
- ✅ Real RegenStaker integration (from octant-v2-core)
- ✅ Full staking and rewards distribution flow

### Verification Checklist

- [x] YDS generates real yield from Aave
- [x] Profit shares minted to AllocationManager
- [x] Weighted votes calculated correctly
- [x] Yield distributed: 10% whale / 15% retail / 75% students
- [x] Student funding recorded in registry
- [x] Epochs transition correctly
- [x] No double redemption possible

---

## 🚀 Getting Started

### Prerequisites

1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. Install [Node.js](https://nodejs.org/)
3. Get an Ethereum RPC URL (Infura, Alchemy, etc.)

### Setup

```bash
# Clone repository
git clone git@github.com:golemfoundation/octant-v2-strategy-foundry-mix.git
cd octant-v2-strategy-foundry-mix

# Install dependencies
forge install
forge soldeer install

# Configure environment
cp .env.example .env
# Edit .env with your ETH_RPC_URL, TEST_ASSET_ADDRESS, TEST_YIELD_SOURCE
```

### Environment Variables

```env
# Required for testing
TEST_ASSET_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  # USDC
TEST_YIELD_SOURCE=0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2   # Aave V3 Pool

# RPC URLs
ETH_RPC_URL=https://mainnet.infura.io/v3/YOUR_API_KEY
```

### Run Tests

```bash
# All tests
make test

# Integration tests only
forge test --match-contract RegenStakerYDSIntegrationTest \
  --fork-url $ETH_RPC_URL \
  --fork-block-number 20000000
```

---

## 📚 Documentation

- **[Project Analysis](./docs/project-analysis.md)** - Deep dive into Octant YDS architecture
- **[Integration Implementation](./docs/regenstaker-integration-implementation.md)** - Technical implementation details
- **[Integration Tests](./docs/integration-tests-summary.md)** - Test suite documentation
- **[Aave Vault Deployment](./docs/aave-vault-deployment.md)** - Deploy ERC-4626 Aave Earn Vault
- **[Aave Vault Testing](./docs/aave-vault-testing.md)** - Visual testing guide with CLI output
- **[Degen 🤝 Regen Manifesto](./docs/regen/degensxregens.md)** - Philosophy and vision

---

## 🎯 Success Criteria

Endaoment succeeds when:

1. ✅ **Yield generates** - Real yield from Aave V3 (verified on fork)
2. ✅ **Profits donated** - 100% of profits minted to AllocationManager
3. ✅ **Voting works** - Weighted votes combine depositor + student power
4. ✅ **Distribution fair** - 10/15/75 split executed correctly
5. ✅ **Students funded** - Funding recorded and distributed
6. ✅ **Scalable** - Protocol handles multiple epochs and vaults
7. ✅ **Public good** - Anyone can participate, no barriers

---

## 🤝 Contributing

This project is part of the **Endaoment** initiative, bridging Degens 🤝 Regens through yield-powered public goods funding.

### Key Principles

- **We believe in Degens** 🎩 ability to discover and spread the word
- **We believe in Regens** 🍄 ability to align towards systemic solutions
- **We believe Degens 🤝 Regens** together multiply coordination and public goods

---

## 📄 License

[Add your license here]

---

## 🙏 Acknowledgments

- **Octant** - YieldDonating Strategy framework
- **Aave** - Yield source protocol
- **RegenStaker** (octant-v2-core) - Student voting power mechanism with full staking and rewards
- **The Degen 🤝 Regen Community** - Inspiration and vision

---

**Join the Movement. Let's Regen Together.** 🌱🎩

*"Speculative energy fuels sustainability. Coordination becomes exponential."*
