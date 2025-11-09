// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IRegenStaker} from "../../interfaces/IRegenStaker.sol";

/**
 * @title MockRegenStaker
 * @notice Mock implementation of RegenStaker for testing
 * @dev Allows setting earning power for addresses to simulate staking
 */
contract MockRegenStaker is IRegenStaker {
    // Mapping of depositor to earning power
    mapping(address => uint256) public depositorTotalEarningPower;

    // Events
    event EarningPowerSet(address indexed depositor, uint256 earningPower);

    /**
     * @notice Set earning power for a depositor (for testing)
     * @param depositor Address of depositor
     * @param earningPower Earning power to set
     */
    function setEarningPower(address depositor, uint256 earningPower) external {
        depositorTotalEarningPower[depositor] = earningPower;
        emit EarningPowerSet(depositor, earningPower);
    }

    /**
     * @notice Increase earning power for a depositor (simulate staking more)
     * @param depositor Address of depositor
     * @param amount Amount to increase earning power by
     */
    function increaseEarningPower(address depositor, uint256 amount) external {
        depositorTotalEarningPower[depositor] += amount;
        emit EarningPowerSet(depositor, depositorTotalEarningPower[depositor]);
    }

    /**
     * @notice Decrease earning power for a depositor (simulate unstaking)
     * @param depositor Address of depositor
     * @param amount Amount to decrease earning power by
     */
    function decreaseEarningPower(address depositor, uint256 amount) external {
        require(depositorTotalEarningPower[depositor] >= amount, "Insufficient earning power");
        depositorTotalEarningPower[depositor] -= amount;
        emit EarningPowerSet(depositor, depositorTotalEarningPower[depositor]);
    }
}

