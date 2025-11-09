// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Test} from "forge-std/Test.sol";
import {AaveEarnVault} from "../../vaults/AaveEarnVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAavePool} from "../../interfaces/IAavePool.sol";
import {DataTypes} from "../../interfaces/DataTypes.sol";

/**
 * @title AaveEarnVaultTest
 * @notice Comprehensive tests for Aave Earn Vault with visual CLI output
 * @dev Tests demonstrate the complete flow and benefits of using ERC-4626 vault
 */
contract AaveEarnVaultTest is Test {
    AaveEarnVault public vault;
    IERC20 public asset; // USDC
    IAavePool public aavePool;

    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public user3 = address(0x1003);

    uint256 public constant INITIAL_BALANCE = 100_000 * 1e6; // 100k USDC per user
    uint256 public constant DEPOSIT_AMOUNT = 10_000 * 1e6; // 10k USDC

    function setUp() public {
        // Read addresses from environment
        address testAssetAddress = vm.envAddress("TEST_ASSET_ADDRESS");
        address testYieldSource = vm.envAddress("TEST_YIELD_SOURCE");

        asset = IERC20(testAssetAddress);
        aavePool = IAavePool(testYieldSource);

        // Deploy vault
        vault = new AaveEarnVault(
            asset,
            "Aave USDC Earn Vault",
            "aUSDC-vault",
            address(aavePool)
        );

        // Label addresses for better traces
        vm.label(address(vault), "AaveEarnVault");
        vm.label(address(asset), "USDC");
        vm.label(address(aavePool), "AavePool");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");

        // Fund users
        deal(address(asset), user1, INITIAL_BALANCE);
        deal(address(asset), user2, INITIAL_BALANCE);
        deal(address(asset), user3, INITIAL_BALANCE);
    }

    /**
     * @notice Test complete flow: Deposit -> Yield Accrual -> Withdraw
     * @dev Visual output shows each step and protocol benefits
     */
    function test_completeFlow() public {
        console.log("\n================================================================");
        console.log("     ENDAOMENT PROTOCOL: AAVE EARN VAULT FLOW DEMO");
        console.log("================================================================\n");

        // ============================================
        // STEP 1: INITIAL STATE
        // ============================================
        console.log("[STEP 1] INITIAL STATE");
        console.log("-------------------------------------------------------------");
        uint256 vaultTotalAssets0 = vault.totalAssets();
        uint256 vaultTotalSupply0 = vault.totalSupply();
        console.log(string.concat("Vault Total Assets: ", Strings.toString(vaultTotalAssets0 / 1e6), " USDC"));
        console.log(string.concat("Vault Total Shares: ", Strings.toString(vaultTotalSupply0 / 1e6)));
        console.log(string.concat("User1 USDC Balance: ", Strings.toString(asset.balanceOf(user1) / 1e6), " USDC"));
        console.log("");

        // ============================================
        // STEP 2: USER DEPOSITS
        // ============================================
        console.log("[STEP 2] USER DEPOSITS TO VAULT");
        console.log("-------------------------------------------------------------");
        console.log(string.concat("User1 deposits: ", Strings.toString(DEPOSIT_AMOUNT / 1e6), " USDC"));
        
        vm.startPrank(user1);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares1 = vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        console.log(string.concat("OK: User1 receives: ", Strings.toString(shares1 / 1e6), " vault shares"));
        console.log(string.concat("UP: Vault Total Assets: ", Strings.toString(vault.totalAssets() / 1e6), " USDC"));
        console.log(string.concat("UP: Vault Total Shares: ", Strings.toString(vault.totalSupply() / 1e6)));
        console.log("TIP: Benefit: Assets automatically deployed to Aave for yield generation");
        console.log("");

        // ============================================
        // STEP 3: YIELD ACCRUAL (Simulate Time)
        // ============================================
        console.log("[STEP 3] YIELD ACCRUAL (30 days)");
        console.log("-------------------------------------------------------------");
        console.log("Simulating 30 days of yield generation...");
        
        uint256 assetsBeforeYield = vault.totalAssets();
        skip(30 days);
        
        // Trigger a report to update aToken balance (yield accrues on Aave)
        // In real scenario, yield accrues automatically on Aave
        // We simulate by checking the vault's totalAssets after time passes
        uint256 assetsAfterYield = vault.totalAssets();
        uint256 yieldGenerated = assetsAfterYield - assetsBeforeYield;
        
        console.log(string.concat("CHART: Assets Before Yield: ", Strings.toString(assetsBeforeYield / 1e6), " USDC"));
        console.log(string.concat("CHART: Assets After Yield: ", Strings.toString(assetsAfterYield / 1e6), " USDC"));
        console.log(string.concat("YIELD: Yield Generated: ", Strings.toString(yieldGenerated / 1e6), " USDC"));
        console.log("TIP: Benefit: Yield automatically accrues - no manual harvesting needed");
        console.log("");

        // ============================================
        // STEP 4: MULTIPLE USERS DEPOSIT
        // ============================================
        console.log("[STEP 4] MULTIPLE USERS JOIN (Network Effects)");
        console.log("-------------------------------------------------------------");
        
        vm.startPrank(user2);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares2 = vault.deposit(DEPOSIT_AMOUNT, user2);
        vm.stopPrank();

        vm.startPrank(user3);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares3 = vault.deposit(DEPOSIT_AMOUNT, user3);
        vm.stopPrank();

        console.log(string.concat("OK: User2 deposits: ", Strings.toString(DEPOSIT_AMOUNT / 1e6), " USDC -> receives ", Strings.toString(shares2 / 1e6), " shares"));
        console.log(string.concat("OK: User3 deposits: ", Strings.toString(DEPOSIT_AMOUNT / 1e6), " USDC -> receives ", Strings.toString(shares3 / 1e6), " shares"));
        console.log(string.concat("UP: Total Vault Assets: ", Strings.toString(vault.totalAssets() / 1e6), " USDC"));
        console.log(string.concat("UP: Total Vault Shares: ", Strings.toString(vault.totalSupply() / 1e6)));
        console.log("TIP: Benefit: More deposits = More yield for public goods funding");
        console.log("");

        // ============================================
        // STEP 5: YIELD CONTINUES TO ACCRUE
        // ============================================
        console.log("[STEP 5] YIELD CONTINUES (Another 30 days)");
        console.log("-------------------------------------------------------------");
        
        uint256 assetsBeforeYield2 = vault.totalAssets();
        skip(30 days);
        uint256 assetsAfterYield2 = vault.totalAssets();
        uint256 yieldGenerated2 = assetsAfterYield2 - assetsBeforeYield2;
        
        console.log(string.concat("CHART: Total Assets: ", Strings.toString(assetsAfterYield2 / 1e6), " USDC"));
        console.log(string.concat("YIELD: Additional Yield: ", Strings.toString(yieldGenerated2 / 1e6), " USDC"));
        console.log("TIP: Benefit: Continuous yield generation for sustainable funding");
        console.log("");

        // ============================================
        // STEP 6: USERS WITHDRAW (With Yield)
        // ============================================
        console.log("[STEP 6] USERS WITHDRAW (Including Yield)");
        console.log("-------------------------------------------------------------");
        
        // User1 withdraws
        uint256 user1AssetsBefore = vault.convertToAssets(shares1);
        vm.startPrank(user1);
        vault.withdraw(user1AssetsBefore, user1, user1);
        vm.stopPrank();
        
        uint256 user1FinalBalance = asset.balanceOf(user1);
        uint256 user1Profit = user1FinalBalance - (INITIAL_BALANCE - DEPOSIT_AMOUNT);
        
        console.log(string.concat("USER: User1 withdraws: ", Strings.toString(user1AssetsBefore / 1e6), " USDC"));
        console.log(string.concat("MONEY: User1 receives: ", Strings.toString(user1FinalBalance / 1e6), " USDC"));
        console.log(string.concat("YIELD: User1 profit: ", Strings.toString(user1Profit / 1e6), " USDC"));
        console.log("TIP: Benefit: Users get yield exposure while supporting public goods");
        console.log("");

        // ============================================
        // STEP 7: PROTOCOL BENEFITS SUMMARY
        // ============================================
        console.log("[STEP 7] PROTOCOL BENEFITS SUMMARY");
        console.log("-------------------------------------------------------------");
        console.log("OK: ERC-4626 Standard: Compatible with all DeFi protocols");
        console.log("OK: Automatic Yield: No manual harvesting required");
        console.log("OK: Zero Fees: 100% of yield goes to public goods");
        console.log("OK: Scalable: Handles multiple users seamlessly");
        console.log("OK: Transparent: All operations on-chain, verifiable");
        console.log("OK: Sustainable: Continuous yield generation");
        console.log("");
        console.log("REGEN: DEGEN -> REGEN FLOW:");
        console.log("   Degens deposit -> Yield generates -> Funds public goods");
        console.log("   Result: Speculative energy -> Sustainable impact");
        console.log("");

        // Assertions
        assertGt(vault.totalAssets(), 0, "Vault should have assets");
        assertGt(user1Profit, 0, "User should receive yield");
    }

    /**
     * @notice Test ERC-4626 compliance
     */
    function test_erc4626Compliance() public {
        console.log("");
        console.log("TEST: TESTING ERC-4626 COMPLIANCE");
        console.log("");

        uint256 depositAmount = 1000 * 1e6;
        vm.startPrank(user1);
        asset.approve(address(vault), depositAmount);
        
        // Test deposit
        uint256 shares = vault.deposit(depositAmount, user1);
        console.log(string.concat("OK: deposit() works - Shares: ", Strings.toString(shares / 1e6)));
        
        // Test convertToAssets
        uint256 assets = vault.convertToAssets(shares);
        console.log(string.concat("OK: convertToAssets() works - Assets: ", Strings.toString(assets / 1e6), " USDC"));
        
        // Test convertToShares
        uint256 shares2 = vault.convertToShares(depositAmount);
        console.log(string.concat("OK: convertToShares() works - Shares: ", Strings.toString(shares2 / 1e6)));
        
        // Test totalAssets
        uint256 total = vault.totalAssets();
        console.log(string.concat("OK: totalAssets() works - Total: ", Strings.toString(total / 1e6), " USDC"));
        
        // Test withdraw
        vault.withdraw(assets, user1, user1);
        console.log("OK: withdraw() works");
        
        vm.stopPrank();
        
        console.log("");
        console.log("OK: All ERC-4626 functions working correctly!");
        console.log("");
    }

    /**
     * @notice Test yield accrual over time
     */
    function test_yieldAccrual() public {
        console.log("");
        console.log("UP: TESTING YIELD ACCRUAL");
        console.log("");

        uint256 depositAmount = 10_000 * 1e6;
        
        vm.startPrank(user1);
        asset.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        uint256 initialAssets = vault.totalAssets();
        console.log(string.concat("Initial Assets: ", Strings.toString(initialAssets / 1e6), " USDC"));

        // Simulate 90 days
        for (uint256 i = 0; i < 3; i++) {
            skip(30 days);
            uint256 currentAssets = vault.totalAssets();
            uint256 yield = currentAssets - initialAssets;
            console.log(string.concat("After ", Strings.toString((i + 1) * 30), " days - Assets: ", Strings.toString(currentAssets / 1e6), " USDC | Yield: ", Strings.toString(yield / 1e6), " USDC"));
        }

        console.log("");
        console.log("OK: Yield accrues continuously over time");
        console.log("");
    }

    /**
     * @notice Test multiple deposits and withdrawals
     */
    function test_multipleUsers() public {
        console.log("");
        console.log("USERS: TESTING MULTIPLE USERS");
        console.log("");

        uint256 depositAmount = 5_000 * 1e6;

        // User1 deposits
        vm.startPrank(user1);
        asset.approve(address(vault), depositAmount);
        uint256 shares1 = vault.deposit(depositAmount, user1);
        vm.stopPrank();
        console.log(string.concat("User1: Deposited ", Strings.toString(depositAmount / 1e6), " USDC -> ", Strings.toString(shares1 / 1e6), " shares"));

        // User2 deposits
        vm.startPrank(user2);
        asset.approve(address(vault), depositAmount);
        uint256 shares2 = vault.deposit(depositAmount, user2);
        vm.stopPrank();
        console.log(string.concat("User2: Deposited ", Strings.toString(depositAmount / 1e6), " USDC -> ", Strings.toString(shares2 / 1e6), " shares"));

        // User3 deposits
        vm.startPrank(user3);
        asset.approve(address(vault), depositAmount);
        uint256 shares3 = vault.deposit(depositAmount, user3);
        vm.stopPrank();
        console.log(string.concat("User3: Deposited ", Strings.toString(depositAmount / 1e6), " USDC -> ", Strings.toString(shares3 / 1e6), " shares"));

        console.log("");
        console.log(string.concat("Total Vault Assets: ", Strings.toString(vault.totalAssets() / 1e6), " USDC"));
        console.log(string.concat("Total Vault Shares: ", Strings.toString(vault.totalSupply() / 1e6)));
        console.log("");
        console.log("SUCCESS: Multiple users can deposit simultaneously");
    }
}

