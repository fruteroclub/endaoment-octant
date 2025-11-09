// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.3.0/contracts/utils/ReentrancyGuard.sol";
import {StudentRegistry} from "./StudentRegistry.sol";
import {StudentVoting} from "./StudentVoting.sol";

/**
 * @title AllocationManager
 * @notice Manages epochs, voting, and yield distribution for YDS vaults
 * @dev Handles 30-day epochs, vote allocation, and 10/15/75 yield split
 *      Integrates with RegenStaker for student voting power and YDS vaults for yield generation
 */
contract AllocationManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Epoch structure
    struct Epoch {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
    }

    // Vote allocation per user per vault per epoch
    mapping(uint256 => mapping(address => mapping(address => mapping(address => uint256)))) public votes;
    // epochId => vault => voter => student => votes

    // Total votes per student per vault per epoch
    mapping(uint256 => mapping(address => mapping(address => uint256))) public studentTotalVotes;
    // epochId => vault => student => votes

    // Total votes cast per vault per epoch
    mapping(uint256 => mapping(address => uint256)) public vaultTotalVotes;

    // Epochs
    Epoch[] public epochs;
    uint256 public currentEpochId;

    // Registered vaults (YDS vaults - ERC-4626)
    mapping(address => bool) public isVaultRegistered;
    mapping(address => address) public vaultWhale; // vault => whale address
    address[] public registeredVaults;

    // Student registry
    StudentRegistry public studentRegistry;

    // Student voting contract
    StudentVoting public studentVoting;

    // Share tracking (from YDS vault profit mints)
    mapping(uint256 => mapping(address => uint256)) public vaultSharesReceived;
    // epochId => vault => shares received
    mapping(uint256 => mapping(address => bool)) public sharesRedeemed;
    // epochId => vault => redeemed flag
    mapping(uint256 => mapping(address => uint256)) public assetsFromRedemption;
    // epochId => vault => assets received from redemption

    // Constants
    uint256 public constant EPOCH_DURATION = 30 days;
    uint256 public constant WHALE_SHARE_BPS = 1000; // 10%
    uint256 public constant RETAIL_SHARE_BPS = 1500; // 15%
    uint256 public constant STUDENT_SHARE_BPS = 7500; // 75%
    uint256 public constant BPS_DENOMINATOR = 10000;

    // Events
    event EpochCreated(uint256 indexed epochId, uint256 startTime, uint256 endTime);
    event EpochFinalized(uint256 indexed epochId);
    event VotesAllocated(
        uint256 indexed epochId, address indexed vault, address indexed voter, address[] students, uint256[] votes
    );
    event SharesRecorded(uint256 indexed epochId, address indexed vault, uint256 shares);
    event SharesRedeemed(
        uint256 indexed epochId,
        address indexed vault,
        uint256 shares,
        uint256 assets
    );
    event YieldDistributed(
        uint256 indexed epochId,
        address indexed vault,
        uint256 totalYield,
        uint256 whaleShare,
        uint256 retailShare,
        uint256 studentShare
    );
    event VaultRegistered(address indexed vault, address indexed whale);

    /**
     * @notice Initialize AllocationManager
     * @param _studentRegistry Address of StudentRegistry contract
     * @param _studentVoting Address of StudentVoting contract
     */
    constructor(address _studentRegistry, address _studentVoting) Ownable(msg.sender) {
        require(_studentRegistry != address(0), "Invalid student registry");
        require(_studentVoting != address(0), "Invalid student voting address");

        studentRegistry = StudentRegistry(_studentRegistry);
        studentVoting = StudentVoting(_studentVoting);

        // Create first epoch
        _createEpoch();

        // Sync epoch with StudentVoting (if allocationManager is set, otherwise will be set later)
        // This allows deployment order flexibility
        try studentVoting.setEpochId(currentEpochId) {} catch {
            // If setEpochId fails (allocationManager not set yet), epoch will be synced later
        }
    }

    /**
     * @notice Register a YDS vault for allocation management
     * @param vault Address of YDS vault (ERC-4626)
     * @param whale Address of vault creator (whale donor)
     */
    function registerVault(address vault, address whale) external onlyOwner {
        require(!isVaultRegistered[vault], "Vault already registered");
        require(vault != address(0), "Invalid vault address");
        require(whale != address(0), "Invalid whale address");

        isVaultRegistered[vault] = true;
        registeredVaults.push(vault);
        vaultWhale[vault] = whale;

        emit VaultRegistered(vault, whale);
    }

    /**
     * @notice Allocate votes to students for current epoch
     * @param vault Address of YDS vault
     * @param students Array of student addresses
     * @param voteAmounts Array of vote amounts (must match user's shares)
     * @dev Votes are weighted by student voting power (earning power from RegenStaker)
     *      Final weight = depositorVotes × studentVotes
     */
    function allocateVotes(address vault, address[] calldata students, uint256[] calldata voteAmounts) external {
        require(isVaultRegistered[vault], "Vault not registered");
        require(students.length == voteAmounts.length, "Array length mismatch");
        require(students.length > 0, "Must allocate to at least one student");
        require(!epochs[currentEpochId].isFinalized, "Epoch is finalized");

        IERC4626 vaultContract = IERC4626(vault);
        uint256 userShares = vaultContract.balanceOf(msg.sender);
        require(userShares > 0, "No shares in vault");

        // Calculate total votes being allocated
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < voteAmounts.length; i++) {
            totalVotes += voteAmounts[i];
        }
        require(totalVotes == userShares, "Vote total must equal shares");

        // Clear previous votes for this user/vault/epoch
        _clearUserVotes(currentEpochId, vault, msg.sender);

        // Allocate new votes (weighted by student voting power)
        uint256 totalWeightedVotes = _allocateWeightedVotes(vault, students, voteAmounts);

        vaultTotalVotes[currentEpochId][vault] += totalWeightedVotes;

        emit VotesAllocated(currentEpochId, vault, msg.sender, students, voteAmounts);
    }

    /**
     * @notice Internal function to allocate weighted votes
     * @param vault Vault address
     * @param students Array of student addresses
     * @param voteAmounts Array of vote amounts
     * @return totalWeightedVotes Total weighted votes allocated
     */
    function _allocateWeightedVotes(
        address vault,
        address[] calldata students,
        uint256[] calldata voteAmounts
    ) internal returns (uint256 totalWeightedVotes) {
        uint256 epochId = currentEpochId;
        address voter = msg.sender;

        for (uint256 i = 0; i < students.length; i++) {
            address student = students[i];
            uint256 voteAmount = voteAmounts[i];

            require(studentRegistry.isStudentActive(student), "Student not active");
            require(voteAmount > 0, "Vote amount must be positive");

            // Calculate weighted vote
            uint256 weightedVote = _calculateWeightedVote(student, voteAmount);

            // Store votes
            votes[epochId][vault][voter][student] = weightedVote;
            studentTotalVotes[epochId][vault][student] += weightedVote;
            totalWeightedVotes += weightedVote;
        }
    }

    /**
     * @notice Calculate weighted vote for a student
     * @param student Student address
     * @param depositorVote Depositor's vote amount
     * @return weightedVote Calculated weighted vote
     */
    function _calculateWeightedVote(address student, uint256 depositorVote) internal view returns (uint256) {
        // Get student's voting power from RegenStaker (earning power)
        uint256 studentVotingPower = studentVoting.getStudentVotingPower(student);

        // Get student's votes for proposals (how they voted for others)
        uint256 studentProposalVotes = studentVoting.getProposalVotes(student);

        // Weighted vote = depositor vote × (student earning power + student proposal votes)
        uint256 studentTotalPower = studentVotingPower + studentProposalVotes;

        // If student has no voting power, use base vote (1:1)
        if (studentTotalPower == 0) {
            return depositorVote;
        }

        // Weighted: depositor vote × student power
        // Use 1e18 as normalization factor (assuming 18 decimals for power)
        uint256 weightedVote = (depositorVote * studentTotalPower) / 1e18;

        // Ensure minimum vote (at least the base vote)
        return weightedVote < depositorVote ? depositorVote : weightedVote;
    }

    /**
     * @notice Finalize current epoch and create next one
     */
    function finalizeEpoch() external onlyOwner {
        require(!epochs[currentEpochId].isFinalized, "Epoch already finalized");
        require(block.timestamp >= epochs[currentEpochId].endTime, "Epoch not ended");

        epochs[currentEpochId].isFinalized = true;
        emit EpochFinalized(currentEpochId);

        // Create next epoch
        currentEpochId++;
        _createEpoch();

        // Sync epoch with StudentVoting
        studentVoting.setEpochId(currentEpochId);
    }

    /**
     * @notice Record shares received from YDS vault (called via event listener or manually)
     * @param epochId Epoch when shares were minted
     * @param vault Vault that minted shares
     * @param shares Amount of shares received
     * @dev Can be called automatically via event listener or manually after epoch finalization
     */
    function recordSharesReceived(
        uint256 epochId,
        address vault,
        uint256 shares
    ) external onlyOwner {
        require(isVaultRegistered[vault], "Vault not registered");
        vaultSharesReceived[epochId][vault] += shares;
        emit SharesRecorded(epochId, vault, shares);
    }

    /**
     * @notice Get current shares balance from vault (for current epoch)
     * @param vault Vault address
     * @return Shares balance held by AllocationManager
     */
    function getVaultSharesBalance(address vault) external view returns (uint256) {
        IERC4626 vaultContract = IERC4626(vault);
        return vaultContract.balanceOf(address(this));
    }

    /**
     * @notice Redeem shares from YDS vault to get underlying assets
     * @param epochId Epoch to redeem for
     * @param vault YDS vault address (ERC-4626)
     * @dev Must be called before distributeYield()
     *      Redeems all shares received from this vault in this epoch
     */
    function redeemVaultShares(
        uint256 epochId,
        address vault
    ) external onlyOwner nonReentrant {
        require(epochs[epochId].isFinalized, "Epoch not finalized");
        require(isVaultRegistered[vault], "Vault not registered");
        require(!sharesRedeemed[epochId][vault], "Shares already redeemed");

        IERC4626 vaultContract = IERC4626(vault);

        // Get shares balance (received from profit mints)
        uint256 sharesToRedeem = vaultSharesReceived[epochId][vault];

        // If no shares recorded, check current balance (fallback)
        if (sharesToRedeem == 0) {
            sharesToRedeem = vaultContract.balanceOf(address(this));
        }

        require(sharesToRedeem > 0, "No shares to redeem");

        // Redeem shares for underlying assets
        uint256 assetsReceived = vaultContract.redeem(
            sharesToRedeem,
            address(this), // receiver of assets
            address(this)  // owner of shares
        );

        // Update state
        sharesRedeemed[epochId][vault] = true;
        assetsFromRedemption[epochId][vault] = assetsReceived;

        emit SharesRedeemed(epochId, vault, sharesToRedeem, assetsReceived);
    }

    /**
     * @notice Distribute yield for a vault in a specific epoch
     * @param epochId Epoch to distribute for
     * @param vault YDS vault address
     * @dev Complete flow: redeem shares → split → distribute
     *      Uses weighted votes (depositor votes × student voting power)
     */
    function distributeYield(uint256 epochId, address vault) external onlyOwner nonReentrant {
        require(epochs[epochId].isFinalized, "Epoch not finalized");
        require(isVaultRegistered[vault], "Vault not registered");

        IERC4626 vaultContract = IERC4626(vault);

        // Redeem shares if not already redeemed
        if (!sharesRedeemed[epochId][vault]) {
            uint256 sharesBalance = vaultContract.balanceOf(address(this));
            if (sharesBalance > 0) {
                uint256 assetsReceived = vaultContract.redeem(
                    sharesBalance,
                    address(this),
                    address(this)
                );
                sharesRedeemed[epochId][vault] = true;
                assetsFromRedemption[epochId][vault] = assetsReceived;
                emit SharesRedeemed(epochId, vault, sharesBalance, assetsReceived);
            }
        }

        // Get assets from redemption
        uint256 availableYield = assetsFromRedemption[epochId][vault];
        require(availableYield > 0, "No yield available");

        // Calculate splits (use remainder for precision)
        uint256 whaleShare = (availableYield * WHALE_SHARE_BPS) / BPS_DENOMINATOR;
        uint256 retailShare = (availableYield * RETAIL_SHARE_BPS) / BPS_DENOMINATOR;
        uint256 studentShare = availableYield - whaleShare - retailShare; // Remainder for precision

        // Get asset token
        IERC20 assetToken = IERC20(vaultContract.asset());

        // Distribute to whale
        address whale = vaultWhale[vault];
        if (whale != address(0) && whaleShare > 0) {
            assetToken.safeTransfer(whale, whaleShare);
        }

        // Distribute to retail (proportional to shares)
        if (retailShare > 0) {
            _distributeToRetail(vault, retailShare, vaultContract, assetToken);
        }

        // Distribute to students (based on weighted votes)
        if (studentShare > 0) {
            _distributeToStudents(epochId, vault, studentShare, assetToken);
        }

        emit YieldDistributed(epochId, vault, availableYield, whaleShare, retailShare, studentShare);
    }

    /**
     * @notice Get current epoch info
     * @return Epoch struct for current epoch
     */
    function getCurrentEpoch() external view returns (Epoch memory) {
        return epochs[currentEpochId];
    }

    /**
     * @notice Get total votes for a student in a vault for an epoch
     * @param epochId Epoch ID
     * @param vault Vault address
     * @param student Student address
     * @return Total votes
     */
    function getStudentVotes(uint256 epochId, address vault, address student) external view returns (uint256) {
        return studentTotalVotes[epochId][vault][student];
    }

    /**
     * @notice Get all registered vaults
     * @return Array of vault addresses
     */
    function getRegisteredVaults() external view returns (address[] memory) {
        return registeredVaults;
    }

    /**
     * @notice Get total number of epochs
     * @return Number of epochs created
     */
    function getEpochCount() external view returns (uint256) {
        return epochs.length;
    }

    /**
     * @notice Create a new epoch
     */
    function _createEpoch() internal {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + EPOCH_DURATION;

        epochs.push(Epoch({id: currentEpochId, startTime: startTime, endTime: endTime, isFinalized: false}));

        emit EpochCreated(currentEpochId, startTime, endTime);
    }

    /**
     * @notice Clear user's previous votes for a vault in an epoch
     * @param epochId Epoch ID
     * @param vault Vault address
     * @param user User address
     */
    function _clearUserVotes(uint256 epochId, address vault, address user) internal {
        address[] memory students = studentRegistry.getAllStudents();

        for (uint256 i = 0; i < students.length; i++) {
            uint256 previousVotes = votes[epochId][vault][user][students[i]];
            if (previousVotes > 0) {
                studentTotalVotes[epochId][vault][students[i]] -= previousVotes;
                votes[epochId][vault][user][students[i]] = 0;
            }
        }
    }

    /**
     * @notice Distribute retail share proportionally to donors
     * @param vault Vault address
     * @param retailShare Total amount for retail
     * @param vaultContract Vault contract instance (ERC-4626)
     * @param assetToken Asset token contract
     */
    function _distributeToRetail(
        address vault,
        uint256 retailShare,
        IERC4626 vaultContract,
        IERC20 assetToken
    ) internal {
        // Get total shares in vault
        uint256 totalShares = vaultContract.totalSupply();

        // Get whale and AllocationManager shares (exclude from retail)
        address whale = vaultWhale[vault];
        uint256 whaleShares = whale != address(0) ? vaultContract.balanceOf(whale) : 0;
        uint256 allocationManagerShares = vaultContract.balanceOf(address(this));

        // Retail shares = total - whale - allocationManager
        uint256 retailShares = totalShares - whaleShares - allocationManagerShares;

        if (retailShares == 0) {
            // No retail participants, return to vault or whale
            return;
        }

        // For MVP: Store retail rewards for participants to claim
        // This requires tracking participants or using a pull pattern
        // For now, we'll use a simplified approach: distribute to all non-whale, non-AllocationManager holders
        // Note: This requires knowing participant list or using events to track

        // Simplified: Transfer to vault (participants can claim later)
        // In production, implement proper participant tracking or pull pattern
        assetToken.safeTransfer(vault, retailShare);
    }

    /**
     * @notice Distribute student share based on weighted votes
     * @param epochId Epoch ID
     * @param vault Vault address
     * @param studentShare Total amount for students
     * @param assetToken Asset token contract
     * @dev Uses weighted votes: depositor votes × student voting power
     */
    function _distributeToStudents(
        uint256 epochId,
        address vault,
        uint256 studentShare,
        IERC20 assetToken
    ) internal {
        address[] memory students = studentRegistry.getActiveStudents();
        uint256 totalWeightedVotes = vaultTotalVotes[epochId][vault];

        if (totalWeightedVotes == 0) {
            // No votes cast - return to vault (conservative)
            assetToken.safeTransfer(vault, studentShare);
            return;
        }

        for (uint256 i = 0; i < students.length; i++) {
            address student = students[i];
            uint256 studentWeightedVotes = studentTotalVotes[epochId][vault][student];

            if (studentWeightedVotes > 0) {
                uint256 studentAmount = (studentShare * studentWeightedVotes) / totalWeightedVotes;
                if (studentAmount > 0) {
                    assetToken.safeTransfer(student, studentAmount);
                    studentRegistry.recordFunding(student, studentAmount);
                }
            }
        }
    }
}

