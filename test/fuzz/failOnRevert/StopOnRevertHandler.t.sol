// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebasePwjToken} from "src/RebasePwjToken.sol";

contract StopOnRevertHandler is Test {
    RebasePwjToken public rebaseToken;
    address public owner;
    address public user;

    constructor(RebasePwjToken _token, address _owner, address _user) {
        rebaseToken = _token;
        owner = _owner;
        user = _user;
    }

    function mintToUser(uint256 amount) external {
        amount = bound(amount, 1, type(uint96).max);
        uint256 userInterestRate = rebaseToken.getGlobalInterestRate();
        rebaseToken.mint(user, amount, userInterestRate);
    }

    function burnFromUser(uint256 amount) external {
        uint256 userBalance = rebaseToken.balanceOf(user);
        amount = bound(amount, 0, userBalance);
        rebaseToken.burn(user, amount);
    }

    function transferUserToOwner(uint256 amount) external {
        uint256 userBalance = rebaseToken.balanceOf(user);
        amount = bound(amount, 0, userBalance);
        vm.prank(user);
        rebaseToken.transfer(owner, amount);
    }

    function transferFromUserToOwner(uint256 amount) external {
        uint256 userBalance = rebaseToken.balanceOf(user);
        amount = bound(amount, 0, userBalance);
        vm.startPrank(user);
        rebaseToken.approve(address(this), amount);
        vm.stopPrank();
        rebaseToken.transferFrom(user, owner, amount);
    }

    function updateGlobalInterestRate(uint256 newRate) external {
        uint256 currentRate = rebaseToken.getGlobalInterestRate();
        if (currentRate <= 1e4) {
            return;
        }
        newRate = bound(newRate, 1e4, currentRate - 1);
        vm.prank(owner);
        rebaseToken.setGlobalInterestRate(newRate);
    }
}
