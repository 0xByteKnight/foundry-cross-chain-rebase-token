// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @author  0xByteKnight
 * @title   RebasePwjToken
 * @notice Rebase PWJ Token is a cross-chain rebase token designed to reward users who deposit assets into a vault.
 *         Balances are dynamic and increase linearly over time, providing a continuously growing yield.
 * @dev Each user is assigned a unique interest rate at the time of deposit, derived from a global rate that can only decrease,
 *      ensuring that early adopters receive a higher yield. The token implements a rebase mechanism where user balances
 *      update (via minting) during key interactions such as minting, burning, transferring, or bridging. Built on the
 *      OpenZeppelin ERC20 standard, the contract is structured to support secure, cross-chain functionality.
 */
contract RebasePwjToken is ERC20, Ownable, AccessControl {
    /*//////////////////////////////////////////////////////////////
                          Type Declarations
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                           State Variables
    //////////////////////////////////////////////////////////////*/

    uint256 private s_globalInterestRate = 5e10;

    mapping(address user => uint256 interestRate) private s_userInterestRate;
    mapping(address user => uint256 lastUpdatedTimestamp) private s_userLastUpdatedTimestamp;

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event InterestRateUpdated(uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

    error RebasePwjToken__NewInterestRateMustDecrease();
    error RebasePwjToken__NewInterestRateCannotBeZero();

    /*//////////////////////////////////////////////////////////////
                              Modifiers
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                              Functions
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("Rebase PWJ Token", "PWJ") Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Grants the mint and burn role to the specified account.
     * @dev Allows the contract owner to assign the MINT_AND_BURN_ROLE to an account, thereby authorizing
     *      it to perform mint and burn operations. Note that this role assignment is centralized and should be
     *      managed carefully to avoid granting excessive power, as the owner can assign the role to themselves
     *      or trusted parties.
     * @param account The address to be granted the mint and burn role.
     */
    function grantMintAndBurnRole(address account) external onlyOwner {
        // TODO: Known issue: Owner can assign himself or trusted party -> Problem of centralization
        grantRole(MINT_AND_BURN_ROLE, account);
    }

    /**
     * @notice Updates the global interest rate for the protocol.
     * @dev Sets a new interest rate that must be strictly lower than the current rate to prevent retroactive yield increases.
     *      If the new rate is not lower, the function reverts with a `RebasePwjToken__NewInterestRateMustDecrease` error.
     * @param newGlobalInterestRate The new global interest rate to be set, which must be lower than the current rate.
     */
    function setGlobalInterestRate(uint256 newGlobalInterestRate) external onlyOwner {
        if (newGlobalInterestRate >= s_globalInterestRate) {
            revert RebasePwjToken__NewInterestRateMustDecrease();
        }
        if (newGlobalInterestRate == 0) {
            revert RebasePwjToken__NewInterestRateCannotBeZero();
        }

        s_globalInterestRate = newGlobalInterestRate;
        emit InterestRateUpdated(newGlobalInterestRate);
    }

    /**
     * @notice Mints new tokens for a user, while accounting for their accrued interest.
     * @dev Before minting, the function updates the user's accrued interest via _mintAccruedInterest, and sets the user's
     *      individual interest rate to the current global rate. Only callable by the contract owner.
     * @param to The address receiving the newly minted tokens.
     * @param amount The number of tokens to mint.
     */
    function mint(address to, uint256 amount, uint256 userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(to);
        s_userInterestRate[to] = userInterestRate;
        _mint(to, amount);
    }

    /**
     * @notice Burns a specified amount of tokens from a user's account.
     * @dev If the provided amount is set to the maximum uint256 value, the function burns the user's entire adjusted balance.
     *      Before burning, the function mints any accrued interest to ensure the balance is fully updated.
     *      This function is restricted to the contract owner.
     * @param from The address from which tokens will be burned.
     * @param amount The number of tokens to burn, or type(uint256).max to burn the full balance.
     */
    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(from);
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           Public Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers tokens from the caller to a specified recipient after updating accrued interest.
     * @dev Overrides the standard ERC20 transfer function by first updating the accrued interest for both the sender and recipient.
     *      If the transfer amount is set to type(uint256).max, it is interpreted as transferring the sender's entire balance.
     *      Additionally, if the recipient has no existing balance, their interest rate is set to that of the sender.
     * @param to The address receiving the tokens.
     * @param amount The number of tokens to transfer, or type(uint256).max to transfer the full balance.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[msg.sender];
        }

        return super.transfer(to, amount);
    }

    /**
     * @notice Transfers tokens from one address to another using the caller's allowance, while updating accrued interest.
     * @dev Overrides the standard ERC20 transferFrom function by updating accrued interest for the caller and the recipient.
     *      If the transfer amount is set to type(uint256).max, it is interpreted as transferring the full balance of the caller.
     *      Additionally, if the recipient's balance is zero, their interest rate is set to that of the sender.
     * @param from The address from which tokens will be transferred.
     * @param to The address receiving the tokens.
     * @param amount The number of tokens to transfer, or type(uint256).max to transfer the full balance.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(from);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[from];
        }

        return super.transferFrom(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints the accrued interest for a specified user.
     * @dev Calculates the difference between the current balance (including accrued interest) and the principal balance
     *      (as stored in the parent ERC20 contract). This difference represents the interest accrued since the last update.
     *      The function then updates the user's last updated timestamp and mints new tokens equal to the accrued interest.
     *      Only callable by the contract owner.
     * @param _user The address of the user for whom the accrued interest is being minted.
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;

        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Calculates the accrued linear interest multiplier for a user.
     * @dev Computes the multiplier by adding the product of the user's interest rate and the time elapsed since their last update
     *      to the precision factor, allowing for fixed-point arithmetic. Only callable internally with owner privileges.
     * @param _user The address of the user for whom to calculate the accrued interest.
     * @return linearInterest The calculated multiplier representing the accrued interest.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = (PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed));
    }

    /*//////////////////////////////////////////////////////////////
                External & Public View & Pure Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current global interest rate used by the protocol.
     * @dev This global rate is used as the baseline for assigning individual interest rates to users at the time of deposit.
     * @return The current global interest rate.
     */
    function getGlobalInterestRate() external view returns (uint256) {
        return s_globalInterestRate;
    }

    /**
     * @notice Retrieves the individual interest rate assigned to the specified user.
     * @dev Returns the rate that was set for the user at the time of their deposit. This value remains unchanged
     *      even if the global interest rate decreases, ensuring that each user's yield is preserved based on their entry point.
     * @param user The address of the user whose interest rate is being queried.
     * @return The interest rate associated with the user.
     */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /**
     * @notice Returns the timestamp when the user's balance was last updated for interest accrual.
     * @dev Useful for determining the duration over which interest has accumulated since the last update.
     * @param user The address of the user.
     * @return The timestamp of the user's last interest update.
     */
    function getUserLastUpdatedTimestamp(address user) external view returns (uint256) {
        return s_userLastUpdatedTimestamp[user];
    }

    /**
     * @notice Returns the underlying principal balance of a user, excluding any accrued interest since last update.
     * @dev This is the balance stored in the base ERC20 contract before applying any interest accrual.
     * @param user The address of the user.
     * @return The principal balance of the user.
     */
    function getPrincipalBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    /**
     * @notice Returns the precision factor used for fixed-point arithmetic in interest calculations.
     * @dev This constant is used to maintain accuracy when calculating accrued interest.
     * @return The precision factor as a uint256 constant.
     */
    function getPrecisionFactor() external pure returns (uint256) {
        return PRECISION_FACTOR;
    }

    /**
     * @notice Returns the balance of a user adjusted for accrued interest.
     * @dev Overrides the standard ERC20 balanceOf function by applying the calculated linear interest multiplier to the user's stored balance.
     *      The multiplier is derived from the time elapsed since the user's last interest update.
     * @param user The address whose balance is being queried.
     * @return The adjusted balance of the user, reflecting accrued interest.
     */
    function balanceOf(address user) public view override returns (uint256) {
        return super.balanceOf(user) * _calculateUserAccumulatedInterestSinceLastUpdate(user) / PRECISION_FACTOR;
    }
}
