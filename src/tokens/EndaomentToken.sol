// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EndaomentToken
 * @notice Mock ERC20 token for Endaoment protocol testing
 * @dev Implements IERC20Permit required by RegenStaker
 *      Mintable by owner for testing purposes
 */
contract EndaomentToken is ERC20, ERC20Permit, Ownable {
    /**
     * @notice Deploy Endaoment Token
     * @param _owner Owner address (can mint tokens)
     */
    constructor(address _owner) ERC20("EnDAOment Token", "ENDAO") ERC20Permit("EnDAOment Token") Ownable(_owner) {}

    /**
     * @notice Mint tokens to an address (owner only)
     * @param to Address to receive tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Batch mint tokens to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to mint (must match recipients length)
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Array length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
}

