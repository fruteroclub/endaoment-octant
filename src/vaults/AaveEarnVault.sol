// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAavePool} from "../interfaces/IAavePool.sol";
import {DataTypes} from "../interfaces/DataTypes.sol";

/**
 * @title AaveEarnVault
 * @notice ERC-4626 compliant vault that wraps Aave V3 Pool for USDC
 * @dev This vault allows users to deposit USDC and earn yield through Aave V3
 *      All yield is passed through to depositors (no fees for public goods)
 */
contract AaveEarnVault is ERC4626 {
    using SafeERC20 for IERC20;

    /// @notice Aave V3 Pool address
    IAavePool public immutable aavePool;

    /// @notice aToken address (cached for gas efficiency)
    address public immutable aToken;

    /**
     * @notice Deploy Aave Earn Vault
     * @param _asset The underlying asset (USDC)
     * @param _name Vault name (e.g., "Aave USDC Earn Vault")
     * @param _symbol Vault symbol (e.g., "aUSDC-vault")
     * @param _aavePool Aave V3 Pool address
     */
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _aavePool
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        require(address(_asset) != address(0), "Invalid asset");
        require(_aavePool != address(0), "Invalid Aave Pool");

        aavePool = IAavePool(_aavePool);

        // Get aToken address from Aave Pool
        DataTypes.ReserveData memory reserveData = aavePool.getReserveData(address(_asset));
        require(reserveData.aTokenAddress != address(0), "aToken not found");
        aToken = reserveData.aTokenAddress;

        // Approve Aave Pool to spend assets
        // Use safeIncreaseAllowance (safeApprove is deprecated in OZ v5)
        _asset.safeIncreaseAllowance(_aavePool, type(uint256).max);
    }

    /**
     * @notice Total assets managed by the vault
     * @return Total amount of underlying assets (including accrued yield)
     */
    function totalAssets() public view override returns (uint256) {
        // Get aToken balance (includes accrued interest)
        uint256 aTokenBalance = IERC20(aToken).balanceOf(address(this));
        
        // Get idle assets in vault
        uint256 idleAssets = IERC20(asset()).balanceOf(address(this));

        // Total = deployed in Aave + idle
        return aTokenBalance + idleAssets;
    }

    /**
     * @notice Deposit assets into Aave Pool
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
        
        // Deploy assets to Aave Pool
        _deployToAave();
    }

    /**
     * @notice Mint shares by depositing assets
     * @param shares Amount of shares to mint
     * @param receiver Address to receive shares
     * @return assets Amount of assets deposited
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = super.mint(shares, receiver);
        
        // Deploy assets to Aave Pool
        _deployToAave();
    }

    /**
     * @notice Withdraw assets from Aave Pool
     * @param assets Amount of assets to withdraw
     * @param receiver Address to receive assets
     * @param owner Address that owns the shares
     * @return shares Amount of shares burned
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        // Withdraw from Aave if needed
        uint256 idleAssets = IERC20(asset()).balanceOf(address(this));
        if (assets > idleAssets) {
            uint256 neededFromAave = assets - idleAssets;
            _withdrawFromAave(neededFromAave);
        }

        shares = super.withdraw(assets, receiver, owner);
    }

    /**
     * @notice Redeem shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive assets
     * @param owner Address that owns the shares
     * @return assets Amount of assets withdrawn
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        assets = convertToAssets(shares);

        // Withdraw from Aave if needed
        uint256 idleAssets = IERC20(asset()).balanceOf(address(this));
        if (assets > idleAssets) {
            uint256 neededFromAave = assets - idleAssets;
            _withdrawFromAave(neededFromAave);
        }

        super.redeem(shares, receiver, owner);
    }

    /**
     * @notice Deploy idle assets to Aave Pool
     * @dev Internal function to supply assets to Aave
     */
    function _deployToAave() internal {
        uint256 idleAssets = IERC20(asset()).balanceOf(address(this));
        if (idleAssets > 0) {
            aavePool.supply(
                address(asset()),
                idleAssets,
                address(this), // onBehalfOf
                0 // referralCode
            );
        }
    }

    /**
     * @notice Withdraw assets from Aave Pool
     * @param amount Amount to withdraw
     * @dev Internal function to withdraw from Aave
     */
    function _withdrawFromAave(uint256 amount) internal {
        aavePool.withdraw(
            address(asset()),
            amount,
            address(this) // to
        );
    }
}

