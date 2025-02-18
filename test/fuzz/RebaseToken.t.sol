// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebasePwjToken} from "src/RebasePwjToken.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract RebaseToken is Test {
    RebasePwjToken rebaseToken;
    Vault vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebasePwjToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        addRewardsToVault(1e18);
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    /*//////////////////////////////////////////////////////////////
                            deposit Tests
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DepositLinear(uint256 amount) public {
        // Arrange
        amount = bound(amount, 1e4, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        // Act
        vault.deposit{value: amount}();

        // Assert
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             redeem Tests
    //////////////////////////////////////////////////////////////*/

    function testFuzz_RedeemStraightAway(uint256 amount) public {
        // Arrange
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // Act
        vault.redeem(type(uint256).max);

        // Assert
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testFuzz_RedeemAfterTimePassed(uint256 amount, uint256 time) public {
        // Arrange

        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterTimePassed = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterTimePassed - amount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterTimePassed - amount);

        // Act
        vm.prank(user);
        vault.redeem(type(uint256).max);

        // Assert
        uint256 ethBalance = address(user).balance;

        assertEq(balanceAfterTimePassed, ethBalance);
        assertGt(ethBalance, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            transfer Tests
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Transfer(uint256 amount, uint256 amountToSend) public {
        // Arrange
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setGlobalInterestRate(4e10);

        // Act
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        // Assert
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }
}
