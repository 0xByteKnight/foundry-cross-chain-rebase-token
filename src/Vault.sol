// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Vault
 * @notice Accepts ETH deposits and mints a rebase token based on the current global interest rate.
 *         Users can also redeem tokens for ETH. Uses a non-reentrant mechanism for security.
 *
 * @dev Emits {Deposit} on deposits and {Redeem} on redemptions.
 *      Reverts with {Vault__RedeemFailed} if ETH transfer fails during redemption.
 */
contract Vault is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                           State Declarations
    //////////////////////////////////////////////////////////////*/

    IRebaseToken private immutable i_rebaseToken;

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

    error Vault__RedeemFailed();

    /*//////////////////////////////////////////////////////////////
                              Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructs a new Vault instance.
     * @param rebaseToken The address of the IRebaseToken contract that the vault interacts with.
     */
    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    /**
     * @notice Fallback function to receive reward.
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                          External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits ETH into the vault and mints an equivalent amount of rebase tokens for the sender.
     * @dev The function calls the rebase token's {mint} function with msg.sender and msg.value.
     *      Emits a {Deposit} event upon successful deposit.
     */
    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getGlobalInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);

        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeems a specified amount of rebase tokens for ETH.
     * @dev Calls the rebase token's {burn} function to burn the tokens from msg.sender.
     *      Afterwards, attempts to transfer the equivalent ETH back to the sender.
     *      If the ETH transfer fails, the function reverts with {Vault__RedeemFailed}.
     *      Emits a {Redeem} event upon successful redemption.
     * @param amount The amount of tokens to redeem.
     */
    function redeem(uint256 amount) external nonReentrant {
        if (amount == type(uint256).max) {
            amount = i_rebaseToken.balanceOf(msg.sender);
        }

        i_rebaseToken.burn(msg.sender, amount);
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }

        emit Redeem(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
               External & Public View & Pure Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the rebase token used by the vault.
     * @return The address of the IRebaseToken contract.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
