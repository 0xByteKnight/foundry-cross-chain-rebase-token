// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@ccip/src/v0.8/ccip/libraries/Pool.sol";
import {IERC20} from "@ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

/**
 * @title RebasePwjTokenPool
 * @notice A cross-chain token pool for RebasePwjToken bridging.
 * @dev Extends the CCIP TokenPool to allow users to lock or burn tokens on the source chain and to release or mint tokens on the destination chain.
 *      The contract encodes/decodes the sender's interest rate for accurate yield calculations during cross-chain transfers.
 */
contract RebasePwjTokenPool is TokenPool {
    /*//////////////////////////////////////////////////////////////
                              Functions
    //////////////////////////////////////////////////////////////*/

    constructor(IERC20 _token, address[] memory _allowList, address _rmnProxy, address _router)
        TokenPool(_token, _allowList, _rmnProxy, _router)
    {}

    /*//////////////////////////////////////////////////////////////
                          External Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Processes a lock or burn request for a cross-chain transfer.
     * @dev This function validates the input using _validateLockOrBurn, then retrieves the sender’s
     *      individual interest rate from the Rebase token. It burns the specified amount from the pool,
     *      and returns a LockOrBurnOutV1 structure containing the destination token address (retrieved via getRemoteToken)
     *      and the encoded sender’s interest rate, which will be used by the remote chain for further processing.
     * @param lockOrBurnIn The input parameters for the lock or burn operation, including the original sender,
     *        amount to burn, and the target remote chain selector.
     * @return lockOrBurnOut The output structure containing the remote token address and encoded interest rate data.
     */
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /**
     * @notice Processes a release or mint request for a cross-chain transfer.
     * @dev This function validates the release or mint request via _validateReleaseOrMint, then decodes the source pool data
     *      to retrieve the sender’s interest rate. It mints tokens to the receiver using the provided amount and interest rate,
     *      and returns a ReleaseOrMintOutV1 structure with the destination amount.
     * @param releaseOrMintIn The input parameters for the release or mint operation, including receiver address, amount to mint,
     *        and the encoded source pool data containing the interest rate.
     * @return A ReleaseOrMintOutV1 structure with the destination amount equal to the amount specified in the request.
     */
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
