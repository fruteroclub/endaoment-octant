// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AaveEarnVault} from "../src/vaults/AaveEarnVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployAaveVault
 * @notice Script to deploy Aave Earn Vault for USDC
 * @dev Run with: forge script script/DeployAaveVault.s.sol:DeployAaveVault --rpc-url $ETH_RPC_URL --broadcast --verify
 */
contract DeployAaveVault is Script {
    // Ethereum Mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Aave Earn Vault
        AaveEarnVault vault = new AaveEarnVault(
            IERC20(USDC),
            "Aave USDC Earn Vault",
            "aUSDC-vault",
            AAVE_POOL
        );

        console.log("Aave Earn Vault deployed at:", address(vault));
        console.log("Asset (USDC):", USDC);
        console.log("Aave Pool:", AAVE_POOL);
        console.log("aToken:", vault.aToken());

        vm.stopBroadcast();
    }
}

