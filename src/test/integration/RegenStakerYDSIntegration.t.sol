// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/console.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Test} from "forge-std/Test.sol";
import {YieldDonatingSetup as Setup, ERC20, IStrategyInterface} from "../yieldDonating/YieldDonatingSetup.sol";
import {YieldDonatingStrategy as Strategy} from "../../strategies/yieldDonating/YieldDonatingStrategy.sol";
import {StudentRegistry} from "../../contracts/StudentRegistry.sol";
import {IStudentRegistry} from "../../interfaces/IStudentRegistry.sol";
import {StudentVoting} from "../../contracts/StudentVoting.sol";
import {AllocationManager} from "../../contracts/AllocationManager.sol";
import {RegenStakerSetup} from "../helpers/RegenStakerSetup.sol";
import {RegenStakerWithoutDelegateSurrogateVotes} from "@octant-core/regen/RegenStakerWithoutDelegateSurrogateVotes.sol";
import {IRegenStaker} from "../../interfaces/IRegenStaker.sol";
import {EndaomentToken} from "../../tokens/EndaomentToken.sol";
import {Staker} from "staker/Staker.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title RegenStakerYDSIntegrationTest
 * @notice Comprehensive integration tests for RegenStaker-AllocationManager-YDS flow
 * @dev Tests the complete flow: student staking → voting → depositor allocation → yield distribution
 */
contract RegenStakerYDSIntegrationTest is Setup, RegenStakerSetup {
    // Note: regenStaker and endaoToken are inherited from RegenStakerSetup
    StudentRegistry public studentRegistry;
    StudentVoting public studentVoting;
    AllocationManager public allocationManager;

    // Deposit IDs for students
    mapping(address => Staker.DepositIdentifier) public studentDepositIds;

    // Test addresses
    address public whale = address(100);
    address public retail1 = address(101);
    address public retail2 = address(102);
    address public student1 = address(200);
    address public student2 = address(201);
    address public student3 = address(202);

    // Test amounts
    uint256 public constant WHALE_DEPOSIT = 100_000 * 1e6; // 100k USDC
    uint256 public constant RETAIL1_DEPOSIT = 1_000 * 1e6; // 1k USDC
    uint256 public constant RETAIL2_DEPOSIT = 500 * 1e6; // 500 USDC
    uint256 public constant STUDENT1_STAKE = 10_000 * 1e18; // 10k tokens
    uint256 public constant STUDENT2_STAKE = 5_000 * 1e18; // 5k tokens
    uint256 public constant STUDENT3_STAKE = 2_000 * 1e18; // 2k tokens

    function setUp() public override {
        // Deploy contracts first (before calling super.setUp which deploys strategy)
        // Deploy RegenStaker and all dependencies using RegenStakerSetup
        address admin = address(this);
        deployRegenStaker(admin);
        // regenStaker and endaoToken are now available from RegenStakerSetup
        vm.label(address(regenStaker), "RegenStaker");

        // Fund RegenStaker with rewards for distribution (1M ENDAO tokens)
        uint256 initialRewards = 1_000_000 * 1e18;
        fundRewards(initialRewards);

        // Deploy StudentRegistry
        studentRegistry = new StudentRegistry();
        vm.label(address(studentRegistry), "StudentRegistry");

        // Deploy StudentVoting
        studentVoting = new StudentVoting(address(regenStaker), address(studentRegistry));
        vm.label(address(studentVoting), "StudentVoting");

        // Deploy AllocationManager (but don't set epoch yet)
        // We'll set allocationManager in StudentVoting first, then manually sync epoch
        allocationManager = new AllocationManager(address(studentRegistry), address(studentVoting));
        vm.label(address(allocationManager), "AllocationManager");

        // Set AllocationManager in StudentRegistry
        vm.prank(studentRegistry.owner());
        studentRegistry.setAllocationManager(address(allocationManager));

        // Set AllocationManager in StudentVoting (allows it to set epoch)
        vm.prank(studentVoting.owner());
        studentVoting.setAllocationManager(address(allocationManager));

        // Manually sync epoch (since constructor tried to call it before allocationManager was set)
        vm.prank(address(allocationManager));
        studentVoting.setEpochId(0);

        // Add students
        vm.prank(studentRegistry.owner());
        studentRegistry.addStudent(student1, "Alice Chen", "MIT", "AI & Robotics");
        vm.prank(studentRegistry.owner());
        studentRegistry.addStudent(student2, "Bob Martinez", "Stanford", "Climate Science");
        vm.prank(studentRegistry.owner());
        studentRegistry.addStudent(student3, "Carol Johnson", "Harvard", "Public Health");

        // Students stake ENDAO tokens to build earning power
        studentDepositIds[student1] = stakeForStudent(student1, STUDENT1_STAKE);
        studentDepositIds[student2] = stakeForStudent(student2, STUDENT2_STAKE);
        studentDepositIds[student3] = stakeForStudent(student3, STUDENT3_STAKE);

        // Verify earning power was set correctly
        assertEq(
            regenStaker.depositorTotalEarningPower(student1),
            STUDENT1_STAKE,
            "Student1 earning power should match stake"
        );
        assertEq(
            regenStaker.depositorTotalEarningPower(student2),
            STUDENT2_STAKE,
            "Student2 earning power should match stake"
        );
        assertEq(
            regenStaker.depositorTotalEarningPower(student3),
            STUDENT3_STAKE,
            "Student3 earning power should match stake"
        );

        // Now call super.setUp() which will deploy strategy
        // But we need to override setUpStrategy to use AllocationManager as donation address
        super.setUp();

        // Redeploy strategy with AllocationManager as donation address
        // The parent setUp deployed strategy with dragonRouter, but we need AllocationManager
        // Deploy new strategy with AllocationManager as donation address
        strategy = IStrategyInterface(
            address(
                new Strategy(
                    yieldSource,
                    address(asset),
                    "YieldDonating Strategy",
                    management,
                    keeper,
                    emergencyAdmin,
                    address(allocationManager), // Use AllocationManager as donation address
                    enableBurning,
                    tokenizedStrategyAddress
                )
            )
        );

        vm.label(address(strategy), "strategy");

        // Label addresses
        vm.label(whale, "whale");
        vm.label(retail1, "retail1");
        vm.label(retail2, "retail2");
        vm.label(student1, "student1");
        vm.label(student2, "student2");
        vm.label(student3, "student3");

        // Fund participants
        airdrop(asset, whale, WHALE_DEPOSIT);
        airdrop(asset, retail1, RETAIL1_DEPOSIT);
        airdrop(asset, retail2, RETAIL2_DEPOSIT);
    }

    /**
     * @notice Test complete integration flow
     * @dev Visual output shows the complete Endaoment protocol flow for judges
     */
    function test_completeIntegrationFlow() public {
        console.log("\n================================================================");
        console.log("     ENDAOMENT PROTOCOL: COMPLETE INTEGRATION FLOW DEMO");
        console.log("================================================================\n");

        // ============================================
        // STEP 1: REGISTER VAULT
        // ============================================
        console.log("[STEP 1] REGISTER YDS VAULT WITH ALLOCATION MANAGER");
        console.log("-------------------------------------------------------------");
        vm.prank(allocationManager.owner());
        allocationManager.registerVault(address(strategy), whale);
        console.log("OK: YDS vault registered with AllocationManager");
        console.log(string.concat("INFO: Whale address: ", vm.toString(whale)));
        console.log(string.concat("INFO: Strategy address: ", vm.toString(address(strategy))));
        console.log("");

        // ============================================
        // STEP 2: DEGENS DEPOSIT TO YDS VAULT
        // ============================================
        console.log("[STEP 2] DEGENS DEPOSIT TO YDS VAULT");
        console.log("-------------------------------------------------------------");

        // Whale deposit
        vm.startPrank(whale);
        asset.approve(address(strategy), WHALE_DEPOSIT);
        strategy.deposit(WHALE_DEPOSIT, whale);
        vm.stopPrank();
        uint256 whaleShares = strategy.balanceOf(whale);
        console.log(string.concat("DEGEN: Whale deposits: ", Strings.toString(WHALE_DEPOSIT / 1e6), " USDC"));
        console.log("SHARES: Whale receives YDS shares");

        // Retail1 deposit
        vm.startPrank(retail1);
        asset.approve(address(strategy), RETAIL1_DEPOSIT);
        strategy.deposit(RETAIL1_DEPOSIT, retail1);
        vm.stopPrank();
        uint256 retail1Shares = strategy.balanceOf(retail1);
        console.log(string.concat("DEGEN: Retail1 deposits: ", Strings.toString(RETAIL1_DEPOSIT / 1e6), " USDC"));
        console.log("SHARES: Retail1 receives YDS shares");

        // Retail2 deposit
        vm.startPrank(retail2);
        asset.approve(address(strategy), RETAIL2_DEPOSIT);
        strategy.deposit(RETAIL2_DEPOSIT, retail2);
        vm.stopPrank();
        uint256 retail2Shares = strategy.balanceOf(retail2);
        console.log(string.concat("DEGEN: Retail2 deposits: ", Strings.toString(RETAIL2_DEPOSIT / 1e6), " USDC"));
        console.log("SHARES: Retail2 receives YDS shares");

        uint256 totalDeposited = WHALE_DEPOSIT + RETAIL1_DEPOSIT + RETAIL2_DEPOSIT;
        console.log(string.concat("TOTAL: Total deposits: ", Strings.toString(totalDeposited / 1e6), " USDC"));
        console.log("TIP: Assets automatically deployed to Aave V3 Pool for yield generation");
        console.log("");

        assertGt(whaleShares, 0, "Whale should have shares");
        assertGt(retail1Shares, 0, "Retail1 should have shares");
        assertGt(retail2Shares, 0, "Retail2 should have shares");

        // ============================================
        // STEP 3: STUDENTS STAKE AND BUILD VOTING POWER
        // ============================================
        console.log("[STEP 3] STUDENTS STAKE ENDAO TOKENS (REAL REGENSTAKER)");
        console.log("-------------------------------------------------------------");
        uint256 student1Stake = regenStaker.depositorTotalEarningPower(student1);
        uint256 student2Stake = regenStaker.depositorTotalEarningPower(student2);
        uint256 student3Stake = regenStaker.depositorTotalEarningPower(student3);
        console.log(string.concat("STAKE: Student1 staked: ", Strings.toString(student1Stake / 1e18), " ENDAO tokens"));
        console.log(string.concat("STAKE: Student2 staked: ", Strings.toString(student2Stake / 1e18), " ENDAO tokens"));
        console.log(string.concat("STAKE: Student3 staked: ", Strings.toString(student3Stake / 1e18), " ENDAO tokens"));
        console.log("TIP: Earning power = voting power (from RegenStaker)");
        console.log("");

        // ============================================
        // STEP 4: STUDENTS VOTE FOR PROPOSALS
        // ============================================
        console.log("[STEP 4] STUDENTS VOTE FOR PROPOSALS");
        console.log("-------------------------------------------------------------");

        // Student1 votes for student2
        uint256 student1VotingPower = studentVoting.getStudentVotingPower(student1);
        vm.prank(student1);
        studentVoting.voteForProposal(student2, student1VotingPower / 2); // Use half of voting power
        console.log(string.concat("VOTE: Student1 voting power: ", Strings.toString(student1VotingPower / 1e18)));
        console.log(
            string.concat("VOTE: Student1 votes for Student2: ", Strings.toString((student1VotingPower / 2) / 1e18))
        );

        // Student2 votes for student3
        uint256 student2VotingPower = studentVoting.getStudentVotingPower(student2);
        vm.prank(student2);
        studentVoting.voteForProposal(student3, student2VotingPower);
        console.log(string.concat("VOTE: Student2 voting power: ", Strings.toString(student2VotingPower / 1e18)));
        console.log(string.concat("VOTE: Student2 votes for Student3: ", Strings.toString(student2VotingPower / 1e18)));

        // Verify votes
        uint256 student2ProposalVotes = studentVoting.getProposalVotes(student2);
        uint256 student3ProposalVotes = studentVoting.getProposalVotes(student3);
        console.log(string.concat("TOTAL: Student2 proposal votes: ", Strings.toString(student2ProposalVotes / 1e18)));
        console.log(string.concat("TOTAL: Student3 proposal votes: ", Strings.toString(student3ProposalVotes / 1e18)));
        console.log("TIP: Students vote for other students' proposals using their staking power");
        console.log("");

        assertGt(student2ProposalVotes, 0, "Student2 should have proposal votes");
        assertGt(student3ProposalVotes, 0, "Student3 should have proposal votes");

        // ============================================
        // STEP 5: DEPOSITORS ALLOCATE VOTES TO STUDENTS
        // ============================================
        console.log("[STEP 5] DEPOSITORS ALLOCATE VOTES TO STUDENTS");
        console.log("-------------------------------------------------------------");

        // Whale: 50% to student1, 50% to student2
        address[] memory whaleStudents = new address[](2);
        whaleStudents[0] = student1;
        whaleStudents[1] = student2;
        uint256[] memory whaleVotes = new uint256[](2);
        whaleVotes[0] = whaleShares / 2;
        whaleVotes[1] = whaleShares / 2;

        vm.prank(whale);
        allocationManager.allocateVotes(address(strategy), whaleStudents, whaleVotes);
        console.log("VOTE: Whale allocates shares to Student1 and Student2");

        // Retail1: 100% to student1
        address[] memory retail1Students = new address[](1);
        retail1Students[0] = student1;
        uint256[] memory retail1Votes = new uint256[](1);
        retail1Votes[0] = retail1Shares;

        vm.prank(retail1);
        allocationManager.allocateVotes(address(strategy), retail1Students, retail1Votes);
        console.log("VOTE: Retail1 allocates shares to Student1");

        // Retail2: 100% to student3
        address[] memory retail2Students = new address[](1);
        retail2Students[0] = student3;
        uint256[] memory retail2Votes = new uint256[](1);
        retail2Votes[0] = retail2Shares;

        vm.prank(retail2);
        allocationManager.allocateVotes(address(strategy), retail2Students, retail2Votes);
        console.log("VOTE: Retail2 allocates shares to Student3");
        console.log("TIP: Depositor votes are weighted by student voting power + proposal votes");
        console.log("");

        // ============================================
        // STEP 6: VERIFY WEIGHTED VOTES
        // ============================================
        console.log("[STEP 6] WEIGHTED VOTE CALCULATION");
        console.log("-------------------------------------------------------------");
        uint256 student1Votes = allocationManager.getStudentVotes(0, address(strategy), student1);
        uint256 student2Votes = allocationManager.getStudentVotes(0, address(strategy), student2);
        uint256 student3Votes = allocationManager.getStudentVotes(0, address(strategy), student3);

        console.log(string.concat("WEIGHTED: Student1 weighted votes: ", Strings.toString(student1Votes / 1e18)));
        console.log(string.concat("WEIGHTED: Student2 weighted votes: ", Strings.toString(student2Votes / 1e18)));
        console.log(string.concat("WEIGHTED: Student3 weighted votes: ", Strings.toString(student3Votes / 1e18)));
        console.log("FORMULA: Weighted Vote = Depositor Vote * (Student Power + Proposal Votes)");
        console.log("");

        assertGt(student1Votes, 0, "Student1 should have weighted votes");
        assertGt(student2Votes, 0, "Student2 should have weighted votes");
        assertGt(student3Votes, 0, "Student3 should have weighted votes");

        // ============================================
        // STEP 7: GENERATE YIELD (SIMULATE TIME PASSAGE)
        // ============================================
        console.log("[STEP 7] YIELD GENERATION FROM AAVE");
        console.log("-------------------------------------------------------------");
        uint256 initialAssets = strategy.totalAssets();
        console.log(string.concat("INITIAL: Strategy total assets: ", Strings.toString(initialAssets / 1e6), " USDC"));

        console.log("TIME: Simulating 30 days for yield accrual...");
        skip(30 days);

        // Report to detect profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        uint256 finalAssets = strategy.totalAssets();
        console.log(string.concat("FINAL: Strategy total assets: ", Strings.toString(finalAssets / 1e6), " USDC"));
        console.log(string.concat("YIELD: Profit generated: ", Strings.toString(profit / 1e6), " USDC"));
        console.log(
            string.concat(
                "YIELD: APY equivalent: ~",
                Strings.toString((profit * 365 * 100) / (initialAssets * 30)),
                "%"
            )
        );
        console.log("TIP: Real yield from Aave V3 Pool on mainnet fork");
        console.log("");

        assertGt(profit, 0, "Profit should be detected");
        assertEq(loss, 0, "Loss should be zero");

        // ============================================
        // STEP 8: PROFIT SHARES MINTED TO ALLOCATION MANAGER
        // ============================================
        console.log("[STEP 8] PROFIT DONATION TO ALLOCATION MANAGER");
        console.log("-------------------------------------------------------------");
        uint256 allocationManagerShares = strategy.balanceOf(address(allocationManager));
        console.log("SHARES: AllocationManager receives YDS profit shares");
        console.log(
            string.concat(
                "VALUE: Shares value: ",
                Strings.toString(strategy.convertToAssets(allocationManagerShares) / 1e6),
                " USDC"
            )
        );
        console.log("TIP: 100% of profit donated (zero fees) - all yield goes to public goods");
        console.log("");

        assertGt(allocationManagerShares, 0, "AllocationManager should receive profit shares");

        // ============================================
        // STEP 9: RECORD SHARES AND FINALIZE EPOCH
        // ============================================
        console.log("[STEP 9] EPOCH FINALIZATION");
        console.log("-------------------------------------------------------------");

        // Record shares received (simulate event listener)
        vm.prank(allocationManager.owner());
        allocationManager.recordSharesReceived(0, address(strategy), allocationManagerShares);
        console.log("OK: Shares recorded for epoch 0");

        // Fast-forward to epoch end and finalize
        console.log("TIME: Fast-forwarding to epoch end (30 days)...");
        skip(30 days);
        vm.prank(allocationManager.owner());
        allocationManager.finalizeEpoch();
        console.log("OK: Epoch 0 finalized, epoch 1 created");
        console.log("");

        // ============================================
        // STEP 10: REDEEM SHARES FOR ASSETS
        // ============================================
        console.log("[STEP 10] REDEEM SHARES FOR ASSETS");
        console.log("-------------------------------------------------------------");
        vm.prank(allocationManager.owner());
        allocationManager.redeemVaultShares(0, address(strategy));
        uint256 redeemedAssets = allocationManager.assetsFromRedemption(0, address(strategy));
        console.log(string.concat("REDEEM: Shares redeemed for: ", Strings.toString(redeemedAssets / 1e6), " USDC"));
        console.log("TIP: Shares converted to USDC for distribution");
        console.log("");

        // ============================================
        // STEP 11: YIELD DISTRIBUTION (10/15/75 SPLIT)
        // ============================================
        console.log("[STEP 11] YIELD DISTRIBUTION");
        console.log("-------------------------------------------------------------");

        // Get balances before distribution
        uint256 whaleBalanceBefore = asset.balanceOf(whale);
        uint256 student1BalanceBefore = asset.balanceOf(student1);
        uint256 student2BalanceBefore = asset.balanceOf(student2);
        uint256 student3BalanceBefore = asset.balanceOf(student3);

        // Distribute yield
        vm.prank(allocationManager.owner());
        allocationManager.distributeYield(0, address(strategy));

        // Calculate distributions
        uint256 whaleReceived = asset.balanceOf(whale) - whaleBalanceBefore;
        uint256 student1Received = asset.balanceOf(student1) - student1BalanceBefore;
        uint256 student2Received = asset.balanceOf(student2) - student2BalanceBefore;
        uint256 student3Received = asset.balanceOf(student3) - student3BalanceBefore;
        uint256 totalYield = allocationManager.assetsFromRedemption(0, address(strategy));

        console.log(string.concat("TOTAL: Total yield to distribute: ", Strings.toString(totalYield / 1e6), " USDC"));
        console.log("");
        console.log("DISTRIBUTION: 10% Whale / 15% Retail / 75% Students");
        console.log("-------------------------------------------------------------");
        console.log(string.concat("WHALE: Whale receives: ", Strings.toString(whaleReceived / 1e6), " USDC (10%)"));
        console.log(string.concat("STUDENT: Student1 receives: ", Strings.toString(student1Received / 1e6), " USDC"));
        console.log(string.concat("STUDENT: Student2 receives: ", Strings.toString(student2Received / 1e6), " USDC"));
        console.log(string.concat("STUDENT: Student3 receives: ", Strings.toString(student3Received / 1e6), " USDC"));

        uint256 totalStudentReceived = student1Received + student2Received + student3Received;
        uint256 retailReceived = totalYield - whaleReceived - totalStudentReceived;
        console.log(
            string.concat("RETAIL: Retail investors receive: ", Strings.toString(retailReceived / 1e6), " USDC (15%)")
        );
        console.log(
            string.concat(
                "STUDENTS: Total student funding: ",
                Strings.toString(totalStudentReceived / 1e6),
                " USDC (75%)"
            )
        );
        console.log("TIP: Distribution based on weighted votes (depositor + student power)");
        console.log("");

        // Whale should receive 10% of yield
        uint256 expectedWhaleShare = (totalYield * 1000) / 10000;
        assertApproxEqRel(whaleReceived, expectedWhaleShare, 0.01e18, "Whale should receive ~10%");

        // Students should receive 75% of yield, distributed by weighted votes
        uint256 expectedStudentShare = (totalYield * 7500) / 10000;
        assertApproxEqRel(totalStudentReceived, expectedStudentShare, 0.01e18, "Students should receive ~75%");

        // All students should receive some funding
        assertGt(student1Received, 0, "Student1 should receive funding");
        assertGt(student2Received, 0, "Student2 should receive funding");
        assertGt(student3Received, 0, "Student3 should receive funding");

        // ============================================
        // STEP 12: VERIFY FUNDING RECORDED
        // ============================================
        console.log("[STEP 12] FUNDING RECORDED IN REGISTRY");
        console.log("-------------------------------------------------------------");
        IStudentRegistry.Student memory student1Data = studentRegistry.getStudent(student1);
        console.log(
            string.concat(
                "RECORD: Student1 total funding received: ",
                Strings.toString(student1Data.totalReceived / 1e6),
                " USDC"
            )
        );
        console.log("RECORD: Student1 name:", student1Data.name);
        console.log("RECORD: Student1 university:", student1Data.university);
        console.log("TIP: All funding tracked on-chain in StudentRegistry");
        console.log("");

        // ============================================
        // SUMMARY: PROTOCOL BENEFITS
        // ============================================
        console.log("================================================================");
        console.log("     PROTOCOL BENEFITS SUMMARY");
        console.log("================================================================\n");
        console.log("DEGEN BENEFITS:");
        console.log("  - Zero fees: 100% of yield donated to public goods");
        console.log("  - Real yield: Generated from Aave V3 on mainnet");
        console.log("  - Voting power: Influence funding allocation");
        console.log("  - Transparent: All operations on-chain\n");
        console.log("REGEN BENEFITS:");
        console.log("  - Sustainable funding: Continuous yield streams");
        console.log("  - Democratic allocation: Weighted voting system");
        console.log("  - Student empowerment: Staking + attestations = voting power");
        console.log("  - Fair distribution: 75% to students, 15% to retail, 10% to whale\n");
        console.log("SYNERGY: Degen energy (yield) -> Regen impact (student funding)");
        console.log("RESULT: Speculative yield becomes sustainable public goods funding");
        console.log("\n================================================================");
        console.log("     ENDAOMENT PROTOCOL DEMO COMPLETE");
        console.log("================================================================\n");

        assertEq(student1Data.totalReceived, student1Received, "Student1 funding should be recorded");
    }

    /**
     * @notice Test weighted vote calculation
     */
    function test_weightedVoteCalculation() public {
        // Register vault
        vm.prank(allocationManager.owner());
        allocationManager.registerVault(address(strategy), whale);

        // Whale deposits
        vm.startPrank(whale);
        asset.approve(address(strategy), WHALE_DEPOSIT);
        strategy.deposit(WHALE_DEPOSIT, whale);
        vm.stopPrank();

        uint256 whaleShares = strategy.balanceOf(whale);

        // Allocate votes to student1 (who has high earning power)
        address[] memory students = new address[](1);
        students[0] = student1;
        uint256[] memory votes = new uint256[](1);
        votes[0] = whaleShares;

        vm.prank(whale);
        allocationManager.allocateVotes(address(strategy), students, votes);

        // Get weighted votes
        uint256 student1Votes = allocationManager.getStudentVotes(0, address(strategy), student1);

        // Weighted vote should be greater than base vote due to student earning power
        // weightedVote = depositorVote × (studentEarningPower + studentProposalVotes) / 1e18
        // Since student1 has 10k earning power, and we normalize by 1e18,
        // if student1VotingPower is 10k * 1e18, then weightedVote = whaleShares * 10k * 1e18 / 1e18 = whaleShares * 10k
        // But we ensure minimum is base vote, so it should be at least whaleShares
        assertGe(student1Votes, whaleShares, "Weighted vote should be at least base vote");

        // If student has no earning power, vote should be base vote
        address student4 = address(203);
        vm.prank(studentRegistry.owner());
        studentRegistry.addStudent(student4, "David Kim", "UC Berkeley", "Renewable Energy");
        // student4 has no earning power (not set in regenStaker)

        // Get current shares (may have changed due to yield)
        uint256 currentWhaleShares = strategy.balanceOf(whale);

        address[] memory students2 = new address[](1);
        students2[0] = student4;
        uint256[] memory votes2 = new uint256[](1);
        votes2[0] = currentWhaleShares; // Allocate all shares

        vm.prank(whale);
        allocationManager.allocateVotes(address(strategy), students2, votes2);

        uint256 student4Votes = allocationManager.getStudentVotes(0, address(strategy), student4);
        // Student4 has no earning power, so should get base vote (1:1)
        assertEq(student4Votes, currentWhaleShares, "Student with no earning power should get base vote");
    }

    /**
     * @notice Test student voting power affects allocation
     */
    function test_studentVotingPowerAffectsAllocation() public {
        // Register vault
        vm.prank(allocationManager.owner());
        allocationManager.registerVault(address(strategy), whale);

        // Whale deposits
        vm.startPrank(whale);
        asset.approve(address(strategy), WHALE_DEPOSIT);
        strategy.deposit(WHALE_DEPOSIT, whale);
        vm.stopPrank();

        uint256 whaleShares = strategy.balanceOf(whale);

        // Allocate equal votes to student1 (high power) and student3 (low power) BEFORE epoch ends
        address[] memory students = new address[](2);
        students[0] = student1; // 10k earning power
        students[1] = student3; // 2k earning power
        uint256[] memory votes = new uint256[](2);
        votes[0] = whaleShares / 2;
        votes[1] = whaleShares / 2;

        vm.prank(whale);
        allocationManager.allocateVotes(address(strategy), students, votes);

        // Generate yield
        skip(30 days);
        vm.prank(keeper);
        strategy.report();

        // Record shares and finalize epoch
        uint256 shares = strategy.balanceOf(address(allocationManager));
        require(shares > 0, "AllocationManager should receive profit shares");
        vm.prank(allocationManager.owner());
        allocationManager.recordSharesReceived(0, address(strategy), shares);

        skip(30 days);
        vm.prank(allocationManager.owner());
        allocationManager.finalizeEpoch();

        // Redeem and distribute
        vm.prank(allocationManager.owner());
        allocationManager.redeemVaultShares(0, address(strategy));

        uint256 student1BalanceBefore = asset.balanceOf(student1);
        uint256 student3BalanceBefore = asset.balanceOf(student3);

        vm.prank(allocationManager.owner());
        allocationManager.distributeYield(0, address(strategy));

        uint256 student1Received = asset.balanceOf(student1) - student1BalanceBefore;
        uint256 student3Received = asset.balanceOf(student3) - student3BalanceBefore;

        // Student1 should receive more due to higher earning power
        assertGt(student1Received, student3Received, "Student1 with higher earning power should receive more");
    }

    /**
     * @notice Test epoch management
     */
    function test_epochManagement() public {
        // Check initial epoch
        AllocationManager.Epoch memory epoch = allocationManager.getCurrentEpoch();
        assertEq(epoch.id, 0, "Initial epoch should be 0");
        assertFalse(epoch.isFinalized, "Initial epoch should not be finalized");

        // Fast-forward to epoch end
        skip(30 days);

        // Finalize epoch
        vm.prank(allocationManager.owner());
        allocationManager.finalizeEpoch();

        // Check new epoch
        epoch = allocationManager.getCurrentEpoch();
        assertEq(epoch.id, 1, "New epoch should be 1");
        assertFalse(epoch.isFinalized, "New epoch should not be finalized");

        // Verify StudentVoting epoch synced
        assertEq(studentVoting.currentEpochId(), 1, "StudentVoting epoch should be synced");
    }

    /**
     * @notice Test share redemption prevents double redemption
     */
    function test_shareRedemptionPreventsDoubleRedemption() public {
        // Register vault
        vm.prank(allocationManager.owner());
        allocationManager.registerVault(address(strategy), whale);

        // Whale deposits to generate yield
        vm.startPrank(whale);
        asset.approve(address(strategy), WHALE_DEPOSIT);
        strategy.deposit(WHALE_DEPOSIT, whale);
        vm.stopPrank();

        // Generate yield and record shares
        skip(30 days);
        vm.prank(keeper);
        strategy.report();

        uint256 shares = strategy.balanceOf(address(allocationManager));
        require(shares > 0, "AllocationManager should receive profit shares");
        vm.prank(allocationManager.owner());
        allocationManager.recordSharesReceived(0, address(strategy), shares);

        skip(30 days);
        vm.prank(allocationManager.owner());
        allocationManager.finalizeEpoch();

        // Redeem once
        vm.prank(allocationManager.owner());
        allocationManager.redeemVaultShares(0, address(strategy));

        // Try to redeem again (should fail)
        vm.prank(allocationManager.owner());
        vm.expectRevert("Shares already redeemed");
        allocationManager.redeemVaultShares(0, address(strategy));
    }
}
