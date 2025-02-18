// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {RebasePwjToken} from "src/RebasePwjToken.sol";
import {StopOnRevertHandler} from "./StopOnRevertHandler.t.sol";

contract StopOnRevertInvariants is StdInvariant, Test {
    RebasePwjToken rebaseToken;
    StopOnRevertHandler handler;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() external {
        vm.startPrank(owner);
        rebaseToken = new RebasePwjToken();

        handler = new StopOnRevertHandler(rebaseToken, owner, user);
        rebaseToken.grantMintAndBurnRole(address(handler));
        handler.mintToUser(10 ether);
        vm.stopPrank();
        targetContract(address(handler));
    }

    function invariant_ownerHasDefaultAdminRole() public view {
        require(rebaseToken.hasRole(rebaseToken.DEFAULT_ADMIN_ROLE(), owner), "Owner lost default admin role.");
    }

    function invariant_balanceIsAtLeastPrincipal() public view {
        uint256 principal = rebaseToken.getPrincipalBalanceOf(user);
        uint256 currentBalance = rebaseToken.balanceOf(user);
        require(
            currentBalance >= principal, "Current balance (with accrued interest) is less than the principal balance."
        );
    }

    function invariant_lastUpdatedNotInFuture() public view {
        uint256 lastUpdated = rebaseToken.getUserLastUpdatedTimestamp(user);
        require(lastUpdated <= block.timestamp, "Last updated timestamp is in the future.");
    }

    function invariant__getterFunctionsCannotRevert() public view {
        rebaseToken.getGlobalInterestRate();
        rebaseToken.getUserInterestRate(owner);
        rebaseToken.getUserLastUpdatedTimestamp(owner);
        rebaseToken.getPrincipalBalanceOf(owner);
        rebaseToken.getPrecisionFactor();
        rebaseToken.balanceOf(owner);
    }
}
