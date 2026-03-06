// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal Aave v3 IPool interface — only functions used by BaseVaultV2
interface IAavePool {
    struct ReserveConfigurationMap {
        uint256 data;
    }

    /// @dev Must match the exact field order and types of Aave v3 DataTypes.ReserveData
    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    /// @notice Supply an ERC-20 asset into the Aave pool
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /// @notice Withdraw an ERC-20 asset from the Aave pool
    /// @return The actual amount withdrawn
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /// @notice Returns reserve data for a given asset
    function getReserveData(address asset) external view returns (ReserveData memory);
}
