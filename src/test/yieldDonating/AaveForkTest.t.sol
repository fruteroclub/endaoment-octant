// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {YieldDonatingSetup as Setup, ERC20, IStrategyInterface, ITokenizedStrategy} from "./YieldDonatingSetup.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AaveEarnVault} from "../../vaults/AaveEarnVault.sol";

/**
 * @title AaveForkTest
 * @notice Comprehensive fork tests for Aave V3 integration with YieldDonating Strategy via Aave Earn Vault
 * @dev Tests yield generation, profit detection, and donation to dragonRouter using ERC-4626 vault
 */
contract AaveForkTest is Setup {
    IERC4626 public vaultInterface;
    AaveEarnVault public aaveVault;

    function setUp() public override {
        super.setUp();
        
        // Cast yield source to IERC4626 (vault)
        vaultInterface = IERC4626(yieldSource);
        aaveVault = AaveEarnVault(address(vaultInterface));
        
        // Label addresses for better traces
        vm.label(address(vaultInterface), "AaveEarnVault");
    }
    
    /**
     * @notice Helper function to get aToken address from vault
     * @dev Gets aToken address from Aave Pool via vault
     */
    function _getATokenAddress() internal view returns (address) {
        return aaveVault.aToken();
    }

    /**
     * @notice Test basic deposit and deployment to vault
     */
    function test_depositDeploysToVault(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        
        // Get initial vault shares balance
        uint256 initialVaultShares = vaultInterface.balanceOf(address(strategy));
        
        // Deposit to strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Verify funds deployed to vault (vault shares should increase)
        uint256 finalVaultShares = vaultInterface.balanceOf(address(strategy));
        assertGt(finalVaultShares, initialVaultShares, "Funds not deployed to vault");
        
        // Verify strategy total assets matches deposit
        assertEq(strategy.totalAssets(), _amount, "Strategy total assets should equal deposit");
    }

    /**
     * @notice Test yield accrual and profit detection
     */
    function test_yieldAccruesAndProfitDetected(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        
        // Deposit to strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Get initial total assets
        uint256 initialAssets = strategy.totalAssets();
        assertEq(initialAssets, _amount, "Initial assets should equal deposit");
        
        // Get initial dragonRouter shares
        uint256 initialDragonShares = strategy.balanceOf(dragonRouter);
        
        // Simulate time passage (30 days) to accrue yield
        skip(30 days);
        
        // Report should detect yield
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();
        
        // Verify profit detected
        assertGt(profit, 0, "Profit should be detected after time passage");
        assertEq(loss, 0, "Loss should be zero");
        
        // Verify profit shares minted to dragonRouter
        uint256 finalDragonShares = strategy.balanceOf(dragonRouter);
        assertGt(finalDragonShares, initialDragonShares, "Dragon router should receive profit shares");
        
        // Verify total assets increased
        uint256 finalAssets = strategy.totalAssets();
        assertGt(finalAssets, initialAssets, "Total assets should increase with yield");
        
        // Verify profit equals the increase in total assets
        assertEq(finalAssets - initialAssets, profit, "Profit should equal asset increase");
    }

    /**
     * @notice Test withdrawal after yield accrual
     */
    function test_withdrawAfterYield(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        
        // Deposit
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Get user's initial share balance
        uint256 userSharesBefore = strategy.balanceOf(user);
        
        // Accrue yield
        skip(30 days);
        vm.prank(keeper);
        strategy.report();
        
        // Get dragonRouter shares after yield
        uint256 dragonSharesAfterYield = strategy.balanceOf(dragonRouter);
        assertGt(dragonSharesAfterYield, 0, "Dragon router should have yield shares");
        
        // Withdraw user's shares
        uint256 userBalanceBefore = asset.balanceOf(user);
        vm.prank(user);
        strategy.redeem(userSharesBefore, user, user);
        
        // User should get at least their principal
        uint256 userBalanceAfter = asset.balanceOf(user);
        assertGe(userBalanceAfter, userBalanceBefore + _amount, "User should get at least principal");
        
        // Dragon router should still have yield shares
        uint256 dragonSharesAfterWithdraw = strategy.balanceOf(dragonRouter);
        assertGt(dragonSharesAfterWithdraw, 0, "Dragon router should keep yield shares");
        assertEq(dragonSharesAfterWithdraw, dragonSharesAfterYield, "Dragon router shares should not decrease");
    }

    /**
     * @notice Test multiple deposits and withdrawals
     */
    function test_multipleDepositsWithdrawals() public {
        uint256 deposit1 = 100_000 * 10 ** decimals;
        uint256 deposit2 = 50_000 * 10 ** decimals;
        
        // First deposit
        mintAndDepositIntoStrategy(strategy, user, deposit1);
        uint256 shares1 = strategy.balanceOf(user);
        
        // Accrue yield
        skip(15 days);
        vm.prank(keeper);
        strategy.report();
        
        // Second deposit
        mintAndDepositIntoStrategy(strategy, user, deposit2);
        uint256 shares2 = strategy.balanceOf(user);
        assertGt(shares2, shares1, "User should have more shares after second deposit");
        
        // Accrue more yield
        skip(15 days);
        vm.prank(keeper);
        strategy.report();
        
        // Partial withdrawal (withdraw first deposit amount)
        vm.prank(user);
        strategy.redeem(shares1, user, user);
        
        // Verify remaining balance
        uint256 remainingShares = strategy.balanceOf(user);
        assertGt(remainingShares, 0, "User should have remaining shares");
        assertLt(remainingShares, shares2, "Remaining shares should be less than before withdrawal");
    }

    /**
     * @notice Test zero yield scenario (immediate report)
     */
    function test_zeroYield() public {
        uint256 _amount = 100_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Report immediately (no time passage = no yield)
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();
        
        // Should have zero profit
        assertEq(profit, 0, "No profit without time passage");
        assertEq(loss, 0, "No loss either");
        
        // Dragon router should have no shares
        uint256 dragonShares = strategy.balanceOf(dragonRouter);
        assertEq(dragonShares, 0, "Dragon router should have no shares without profit");
    }

    /**
     * @notice Test high yield scenario (long time passage)
     */
    function test_highYieldScenario() public {
        uint256 _amount = 1_000_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Simulate long time passage (1 year)
        skip(365 days);
        
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();
        
        // Should have significant profit
        assertGt(profit, 0, "Should have profit after 1 year");
        
        // Profit should be reasonable percentage (e.g., 2-10% APY)
        uint256 profitBps = (profit * 10_000) / _amount;
        assertGt(profitBps, 100, "Profit should be at least 1%");
        assertLt(profitBps, 2000, "Profit should be reasonable (<20%)");
        
        // Verify dragon router received shares
        uint256 dragonShares = strategy.balanceOf(dragonRouter);
        assertGt(dragonShares, 0, "Dragon router should have shares");
        
        // Convert shares to assets to verify
        uint256 dragonAssets = strategy.convertToAssets(dragonShares);
        assertEq(dragonAssets, profit, "Dragon router assets should equal profit");
    }

    /**
     * @notice Test vault shares value increases over time (yield accrual)
     */
    function test_vaultSharesValueIncreases() public {
        uint256 _amount = 100_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Get initial vault shares and their asset value
        uint256 initialVaultShares = vaultInterface.balanceOf(address(strategy));
        uint256 initialVaultAssets = vaultInterface.convertToAssets(initialVaultShares);
        
        // Skip time
        skip(30 days);
        
        // Get vault shares and asset value after time passage
        uint256 finalVaultShares = vaultInterface.balanceOf(address(strategy));
        uint256 finalVaultAssets = vaultInterface.convertToAssets(finalVaultShares);
        
        // Vault shares value should increase (interest accrues)
        assertGt(finalVaultAssets, initialVaultAssets, "Vault assets should increase with interest");
    }

    /**
     * @notice Test that idle funds are accounted for in _harvestAndReport
     */
    function test_idleFundsAccounted() public {
        uint256 _amount = 100_000 * 10 ** decimals;
        
        // Deposit
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Get initial state
        uint256 vaultSharesBefore = vaultInterface.balanceOf(address(strategy));
        uint256 vaultAssetsBefore = vaultInterface.convertToAssets(vaultSharesBefore);
        uint256 idleBefore = asset.balanceOf(address(strategy));
        uint256 totalAssets1 = strategy.totalAssets();
        assertEq(totalAssets1, _amount, "Initial total assets should equal deposit");
        
        // Manually send some asset to strategy (simulating idle funds)
        uint256 idleAmount = 10_000 * 10 ** decimals;
        airdrop(asset, address(strategy), idleAmount);
        
        // Verify idle balance increased
        uint256 idleAfter = asset.balanceOf(address(strategy));
        assertGe(idleAfter, idleBefore + idleAmount, "Idle balance should increase");
        
        // Force a report to update totalAssets accounting
        vm.prank(keeper);
        strategy.report();
        
        // Get total assets after report (should include idle)
        uint256 totalAssets2 = strategy.totalAssets();
        
        // Verify that total assets equals deployed (vault assets) + idle
        uint256 vaultSharesAfter = vaultInterface.balanceOf(address(strategy));
        uint256 vaultAssetsAfter = vaultInterface.convertToAssets(vaultSharesAfter);
        uint256 currentIdle = asset.balanceOf(address(strategy));
        uint256 calculatedTotal = vaultAssetsAfter + currentIdle;
        
        // After report, total assets should equal vault assets + idle
        assertEq(totalAssets2, calculatedTotal, "Total assets should equal vault assets + idle after report");
        assertGe(totalAssets2, totalAssets1, "Total assets should be at least equal to before");
    }

    /**
     * @notice Test emergency withdrawal scenario
     */
    function test_emergencyWithdraw() public {
        uint256 _amount = 100_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // Shutdown strategy
        vm.prank(emergencyAdmin);
        ITokenizedStrategy(address(strategy)).shutdownStrategy();
        
        // User should still be able to withdraw
        uint256 userShares = strategy.balanceOf(user);
        uint256 userBalanceBefore = asset.balanceOf(user);
        
        vm.prank(user);
        strategy.redeem(userShares, user, user);
        
        uint256 userBalanceAfter = asset.balanceOf(user);
        assertGe(userBalanceAfter, userBalanceBefore + _amount, "User should be able to withdraw after shutdown");
    }

    /**
     * @notice Test that profit is correctly calculated across multiple reports
     */
    function test_multipleReports() public {
        uint256 _amount = 100_000 * 10 ** decimals;
        mintAndDepositIntoStrategy(strategy, user, _amount);
        
        // First report after 15 days
        skip(15 days);
        vm.prank(keeper);
        (uint256 profit1, uint256 loss1) = strategy.report();
        assertGt(profit1, 0, "First report should show profit");
        
        uint256 dragonShares1 = strategy.balanceOf(dragonRouter);
        
        // Second report after another 15 days
        skip(15 days);
        vm.prank(keeper);
        (uint256 profit2, uint256 loss2) = strategy.report();
        assertGt(profit2, 0, "Second report should show profit");
        
        uint256 dragonShares2 = strategy.balanceOf(dragonRouter);
        assertGt(dragonShares2, dragonShares1, "Dragon router should accumulate more shares");
        
        // Total profit should be sum of both reports
        uint256 totalProfit = profit1 + profit2;
        uint256 totalDragonAssets = strategy.convertToAssets(dragonShares2);
        assertEq(totalDragonAssets, totalProfit, "Total dragon assets should equal total profit");
    }
}

