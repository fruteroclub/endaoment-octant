// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IRegenStaker
 * @notice Interface for RegenStaker to get student earning power (voting power)
 * @dev Simplified interface for getting depositor earning power
 */
interface IRegenStaker {
    /**
     * @notice Get total earning power for a depositor
     * @param depositor Address of the depositor
     * @return Total earning power (voting power) for the depositor
     */
    function depositorTotalEarningPower(address depositor) external view returns (uint256);
}

