// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebasePwjToken} from "src/RebasePwjToken.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract VaultTest is Test {
    RebasePwjToken rebaseToken;
    Vault vault;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant STARTING_USER_BALANCE = 5 ether;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    modifier fundsDeposited() {
        vm.startPrank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}();
        vm.stopPrank();
        _;
    }

    function setUp() public {
        vm.deal(user, STARTING_USER_BALANCE);

        vm.startPrank(owner);
        rebaseToken = new RebasePwjToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            deposit Tests
    //////////////////////////////////////////////////////////////*/

    function test_Deposit() public {
        // Arrange
        vm.expectEmit(true, false, false, true, address(vault));
        emit Deposit(user, DEPOSIT_AMOUNT);

        vm.startPrank(user);

        // Act
        vault.deposit{value: DEPOSIT_AMOUNT}();
        vm.stopPrank();

        // Assert
        uint256 tokenBalance = rebaseToken.balanceOf(user);
        assertEq(tokenBalance, DEPOSIT_AMOUNT, "User token balance should equal the deposit amount");
    }

    /*//////////////////////////////////////////////////////////////
                             redeem Tests
    //////////////////////////////////////////////////////////////*/

    function test_RedeemAllWithMaxUint() public fundsDeposited {
        // Arrange
        uint256 amountToRedeem = type(uint256).max;

        vm.expectEmit(true, false, false, true, address(vault));
        emit Redeem(user, rebaseToken.balanceOf(user));

        // Act
        vm.startPrank(user);
        vault.redeem(amountToRedeem);
        vm.stopPrank();

        // Assert
        uint256 tokenBalanceAfter = rebaseToken.balanceOf(user);
        assertEq(tokenBalanceAfter, 0, "Redeem should burn all tokens");

        uint256 vaultEthBalance = address(vault).balance;
        assertEq(vaultEthBalance, 0, "Vault ETH balance should be zero after redeem");

        assertEq(address(user).balance, STARTING_USER_BALANCE);
    }

    function test_RedeemPartially() public fundsDeposited {
        // Arrange
        uint256 amountToRedeem = rebaseToken.balanceOf(user) / 2;

        vm.expectEmit(true, false, false, true, address(vault));
        emit Redeem(user, amountToRedeem);

        // Act
        vm.startPrank(user);
        vault.redeem(amountToRedeem);
        vm.stopPrank();

        // Assert
        uint256 tokenBalanceAfter = rebaseToken.balanceOf(user);
        assertEq(tokenBalanceAfter, DEPOSIT_AMOUNT / 2, "Redeem should burn all tokens");

        uint256 vaultEthBalance = address(vault).balance;
        assertEq(vaultEthBalance, DEPOSIT_AMOUNT / 2, "Vault ETH balance should be zero after redeem");

        assertEq(rebaseToken.balanceOf(user), amountToRedeem);
    }

    function test_RedeemMoreThanBalance() public fundsDeposited {
        // Arrange
        vm.expectRevert();
        vm.startPrank(user);

        // Act & Assert:
        vault.redeem(DEPOSIT_AMOUNT + 1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     getRebaseTokenAddress Tests
    //////////////////////////////////////////////////////////////*/

    function test_GetRebaseTokenAddress() public view {
        address tokenAddr = vault.getRebaseTokenAddress();
        assertEq(tokenAddr, address(rebaseToken), "Vault should return the correct rebase token address");
    }
}
