// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal Aave v3 IWETHGateway interface — only functions used by BaseVaultV2
interface IWETHGateway {
    /// @notice Wrap ETH and supply to Aave pool on behalf of `onBehalfOf`
    /// @dev Caller must send ETH as msg.value
    function depositETH(address pool, address onBehalfOf, uint16 referralCode) external payable;

    /// @notice Withdraw ETH from Aave pool and send to `to`
    /// @dev Caller must approve the gateway to pull aWETH before calling this
    function withdrawETH(address pool, uint256 amount, address to) external;
}
