// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RegenStakerWithoutDelegateSurrogateVotes} from "@octant-core/regen/RegenStakerWithoutDelegateSurrogateVotes.sol";
import {RegenEarningPowerCalculator} from "@octant-core/regen/RegenEarningPowerCalculator.sol";
import {AddressSet} from "src/utils/AddressSet.sol";
import {IAddressSet} from "src/utils/IAddressSet.sol";
import {AccessMode} from "src/constants.sol";
import {Staker} from "staker/Staker.sol";
import {EndaomentToken} from "../../tokens/EndaomentToken.sol";

/**
 * @title RegenStakerSetup
 * @notice Helper contract to deploy and configure RegenStaker for testing
 * @dev Deploys all required components: token, calculator, address set, and RegenStaker
 */
contract RegenStakerSetup is Test {
    // Deployed contracts
    EndaomentToken public endaoToken;
    RegenEarningPowerCalculator public earningPowerCalculator;
    AddressSet public allocationMechanismAllowset;
    RegenStakerWithoutDelegateSurrogateVotes public regenStaker;

    // Configuration
    address public admin;
    uint128 public constant REWARD_DURATION = 30 days;
    uint128 public constant MINIMUM_STAKE_AMOUNT = 1e18; // 1 ENDAO token
    uint256 public constant MAX_BUMP_TIP = 0; // No tips for testing

    /**
     * @notice Deploy all RegenStaker components
     * @param _admin Admin address for contracts
     */
    function deployRegenStaker(address _admin) public returns (RegenStakerWithoutDelegateSurrogateVotes) {
        admin = _admin;

        // 1. Deploy ENDAO token
        endaoToken = new EndaomentToken(_admin);
        vm.label(address(endaoToken), "ENDAO");

        // 2. Deploy RegenEarningPowerCalculator with AccessMode.NONE (open staking)
        earningPowerCalculator = new RegenEarningPowerCalculator(
            _admin, // owner
            IAddressSet(address(0)), // allowset (not used in NONE mode)
            IAddressSet(address(0)), // blockset (not used in NONE mode)
            AccessMode.NONE // open staking
        );
        vm.label(address(earningPowerCalculator), "RegenEarningPowerCalculator");

        // 3. Deploy AddressSet for allocationMechanismAllowset (required, cannot be address(0))
        // AddressSet constructor takes no parameters (uses msg.sender as owner)
        allocationMechanismAllowset = new AddressSet();
        vm.label(address(allocationMechanismAllowset), "AllocationMechanismAllowset");

        // 4. Deploy RegenStakerWithoutDelegateSurrogateVotes
        // Match octant test pattern: declare as AddressSet, cast to IAddressSet when passing
        regenStaker = new RegenStakerWithoutDelegateSurrogateVotes(
            IERC20(address(endaoToken)), // rewardsToken (same as stake token for compounding)
            IERC20(address(endaoToken)), // stakeToken
            earningPowerCalculator, // earningPowerCalculator
            MAX_BUMP_TIP, // maxBumpTip
            _admin, // admin
            REWARD_DURATION, // rewardDuration
            MINIMUM_STAKE_AMOUNT, // minimumStakeAmount
            IAddressSet(address(0)), // stakerAllowset (not used in NONE mode)
            IAddressSet(address(0)), // stakerBlockset (not used in NONE mode)
            AccessMode.NONE, // stakerAccessMode (open staking)
            IAddressSet(address(allocationMechanismAllowset)) // allocationMechanismAllowset (required)
        );
        vm.label(address(regenStaker), "RegenStaker");

        return regenStaker;
    }

    /**
     * @notice Fund RegenStaker with rewards for distribution
     * @param rewardAmount Amount of ENDAO tokens to add as rewards
     */
    function fundRewards(uint256 rewardAmount) public {
        // Mint tokens to this contract
        vm.prank(admin);
        endaoToken.mint(address(this), rewardAmount);

        // Approve RegenStaker to spend rewards
        endaoToken.approve(address(regenStaker), rewardAmount);

        // Notify RegenStaker of rewards
        regenStaker.notifyRewardAmount(rewardAmount);
    }

    /**
     * @notice Helper to stake tokens for a student
     * @param student Student address
     * @param amount Amount of ENDAO tokens to stake
     * @return depositId Deposit ID from RegenStaker
     */
    function stakeForStudent(address student, uint256 amount) public returns (Staker.DepositIdentifier depositId) {
        // Fund student with tokens
        vm.prank(admin);
        endaoToken.mint(student, amount);

        // Student approves RegenStaker
        vm.prank(student);
        endaoToken.approve(address(regenStaker), amount);

        // Student stakes tokens
        vm.prank(student);
        depositId = regenStaker.stake(amount, student, student); // delegatee=self, claimer=self

        return depositId;
    }

    /**
     * @notice Get earning power for a depositor
     * @param depositor Depositor address
     * @return Earning power
     */
    function getEarningPower(address depositor) public view returns (uint256) {
        return regenStaker.depositorTotalEarningPower(depositor);
    }
}

