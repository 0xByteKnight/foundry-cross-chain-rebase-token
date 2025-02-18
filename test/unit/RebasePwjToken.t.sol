// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebasePwjToken} from "src/RebasePwjToken.sol";
import {RebasePwjTokenHarness} from "test/RebasePwjTokenHarness.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract RebasePwjTokenTest is Test {
    RebasePwjToken rebaseToken;
    RebasePwjTokenHarness rebaseTokenHarness;
    Vault vault;

    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");
    address public owner = makeAddr("owner");

    uint256 public constant STARTING_BALANCE = 10e18;
    uint256 public constant NEW_GLOBAL_INTEREST_RATE = 4e10;
    uint256 public constant AMOUNT_TO_MINT = 10e18;
    uint256 public constant TRANSFER_AMOUNT = 4e18;

    event InterestRateUpdated(uint256 newInterestRate);

    modifier globalInterestRateSet() {
        vm.startPrank(owner);
        rebaseToken.setGlobalInterestRate(NEW_GLOBAL_INTEREST_RATE);
        vm.stopPrank();
        _;
    }

    modifier rebaseTokensMinted() {
        vm.startPrank(address(vault));
        uint256 userInterestRate = rebaseToken.getGlobalInterestRate();
        rebaseToken.mint(user, AMOUNT_TO_MINT, userInterestRate);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebasePwjToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.deal(address(vault), STARTING_BALANCE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          constructor Tests
    //////////////////////////////////////////////////////////////*/

    function test_OwnerHasDefaultAdminRole() public view {
        // Arrange & Act & Assert
        bytes32 defaultAdminRole = rebaseToken.DEFAULT_ADMIN_ROLE();
        bool hasRole = rebaseToken.hasRole(defaultAdminRole, owner);
        assertTrue(hasRole, "Owner should have the default admin role");
    }

    /*//////////////////////////////////////////////////////////////
                      grantMintAndBurnRole Tests
    //////////////////////////////////////////////////////////////*/

    function test_OnlyOwnerCanGrantMintAndBurnRole() public {
        // Arrange
        vm.expectRevert();

        // Act & Assert
        vm.startPrank(user);
        rebaseToken.grantMintAndBurnRole(user);
        vm.stopPrank();
    }

    function test_GrantMintAndBurnRole() public {
        // Arrange
        vm.startPrank(owner);

        // Act
        rebaseToken.grantMintAndBurnRole(user);
        vm.stopPrank();

        // Assert
        bool hasRole = rebaseToken.hasRole(keccak256("MINT_AND_BURN_ROLE"), user);
        assertTrue(hasRole, "User should have the MINT_AND_BURN_ROLE");
    }

    /*//////////////////////////////////////////////////////////////
                        setInterestRate Tests
    //////////////////////////////////////////////////////////////*/

    function test_OnlyOwnerCanSetGlobalInterestRate() public {
        // Arrange
        vm.expectRevert();
        vm.startPrank(user);

        // Act & Assert
        rebaseToken.setGlobalInterestRate(NEW_GLOBAL_INTEREST_RATE);
        vm.stopPrank();
    }

    function test_RevertIfNewGlobalInterestRateIsHigher() public {
        // Arrange
        uint256 globalInterestRate = 6e10;
        vm.expectRevert(RebasePwjToken.RebasePwjToken__NewInterestRateMustDecrease.selector);
        vm.startPrank(owner);

        // Act & Assert
        rebaseToken.setGlobalInterestRate(globalInterestRate);
        vm.stopPrank();
    }

    function test_RevertIfNewGlobalInterestRateIsZero() public {
        // Arrange
        vm.expectRevert(RebasePwjToken.RebasePwjToken__NewInterestRateCannotBeZero.selector);
        vm.startPrank(owner);

        // Act & Assert
        rebaseToken.setGlobalInterestRate(0);
        vm.stopPrank();
    }

    function test_CanSetGlobalInterestRate() public {
        // Arrange
        vm.expectEmit(true, true, true, true, address(rebaseToken));
        emit InterestRateUpdated(NEW_GLOBAL_INTEREST_RATE);
        vm.startPrank(owner);

        // Act
        rebaseToken.setGlobalInterestRate(NEW_GLOBAL_INTEREST_RATE);

        // Assert
        assertEq(rebaseToken.getGlobalInterestRate(), NEW_GLOBAL_INTEREST_RATE);
    }

    /*//////////////////////////////////////////////////////////////
                              mint Tests
    //////////////////////////////////////////////////////////////*/

    function test_OnlyAccountWithGrantedMintAndBurnRoleCanMint() public {
        // Arrange
        vm.expectRevert();
        vm.startPrank(owner);

        // Act & Assert
        rebaseToken.mint(user, AMOUNT_TO_MINT, 0);
        vm.stopPrank();
    }

    function test_AuthorizedAccountCanMint() public {
        // Arrange
        vm.startPrank(address(vault));
        uint256 userInterestRate = rebaseToken.getGlobalInterestRate();

        // Act
        rebaseToken.mint(user, AMOUNT_TO_MINT, userInterestRate);

        // Assert
        assertEq(rebaseToken.getUserInterestRate(user), rebaseToken.getGlobalInterestRate());
        assertEq(rebaseToken.balanceOf(user), AMOUNT_TO_MINT);
    }

    function test_CanMint() public globalInterestRateSet {
        // Arrange
        vm.startPrank(address(vault));
        uint256 userInterestRate = rebaseToken.getGlobalInterestRate();

        // Act
        rebaseToken.mint(user, AMOUNT_TO_MINT, userInterestRate);
        vm.stopPrank();

        // Assert
        assertEq(rebaseToken.balanceOf(user), AMOUNT_TO_MINT);
        assertEq(rebaseToken.getUserInterestRate(user), rebaseToken.getGlobalInterestRate());
    }

    /*//////////////////////////////////////////////////////////////
                              burn Tests
    //////////////////////////////////////////////////////////////*/

    function test_OnlyAccountWithGrantedMintAndBurnRoleCanBurn() public globalInterestRateSet rebaseTokensMinted {
        // Arrange
        vm.expectRevert();
        vm.startPrank(address(owner));

        // Act & Assert
        rebaseToken.burn(user, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testCanBurn() public globalInterestRateSet rebaseTokensMinted {
        // Arrange
        vm.startPrank(address(vault));

        // Act
        rebaseToken.burn(user, AMOUNT_TO_MINT);

        // Assert
        assertEq(rebaseToken.balanceOf(user), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            transfer Tests
    //////////////////////////////////////////////////////////////*/

    function test_StandardTransfer() public rebaseTokensMinted {
        // Arrange
        uint256 userBalanceBefore = rebaseToken.balanceOf(user);
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        uint256 recipientBalanceBefore = rebaseToken.balanceOf(recipient);

        // Act
        vm.startPrank(user);
        bool success = rebaseToken.transfer(recipient, TRANSFER_AMOUNT);
        vm.stopPrank();

        // Assert
        assertTrue(success, "Transfer failed.");

        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        assertEq(userBalanceAfter, userBalanceBefore - TRANSFER_AMOUNT, "Sender balance should decrease correctly.");

        uint256 recipientBalanceAfter = rebaseToken.balanceOf(recipient);
        assertEq(recipientBalanceBefore, 0, "Recipient starting balance has to be 0");
        assertEq(recipientBalanceAfter, TRANSFER_AMOUNT, "Recipient balance should equal transferred amount.");

        uint256 recipientInterestRate = rebaseToken.getUserInterestRate(recipient);
        assertEq(recipientInterestRate, userInterestRate, "Recipient interest rate should match user's.");
    }

    function test_TransferAllWithMax() public rebaseTokensMinted {
        // Arrange
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);

        // Act
        vm.startPrank(user);
        bool success = rebaseToken.transfer(recipient, type(uint256).max);
        vm.stopPrank();

        // Assert
        assertTrue(success, "Transfer with max amount should succeed.");

        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        assertEq(userBalanceAfter, 0, "User balance should be zero after transferring all tokens.");

        uint256 recipientBalanceAfter = rebaseToken.balanceOf(recipient);
        assertEq(recipientBalanceAfter, AMOUNT_TO_MINT, "Recipient balance should equal the full transferred amount.");

        uint256 recipientInterestRate = rebaseToken.getUserInterestRate(recipient);
        assertEq(recipientInterestRate, userInterestRate, "Recipient interest rate should match sender's.");
    }

    /*//////////////////////////////////////////////////////////////
                          transferFrom Tests
    //////////////////////////////////////////////////////////////*/

    function test_TransferFromStandard() public rebaseTokensMinted {
        // Arrange
        vm.startPrank(user);
        rebaseToken.approve(owner, TRANSFER_AMOUNT);
        vm.stopPrank();

        uint256 userBalanceBefore = rebaseToken.balanceOf(user);
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);

        uint256 recipientBalanceBefore = rebaseToken.balanceOf(recipient);

        // Act
        vm.startPrank(owner);
        bool success = rebaseToken.transferFrom(user, recipient, TRANSFER_AMOUNT);
        vm.stopPrank();

        // Assert
        assertEq(recipientBalanceBefore, 0, "Recipient initial balance should be zero.");
        assertTrue(success, "Transfer failed.");

        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        uint256 recipientBalanceAfter = rebaseToken.balanceOf(recipient);

        assertEq(userBalanceAfter, userBalanceBefore - TRANSFER_AMOUNT, "User balance should decrease correctly.");
        assertEq(recipientBalanceAfter, TRANSFER_AMOUNT, "Recipient balance should equal transfer amount.");

        uint256 recipientInterestRate = rebaseToken.getUserInterestRate(recipient);
        assertEq(recipientInterestRate, userInterestRate, "Recipient interest rate should match sender's.");
    }

    function test_TransferFromMax() public rebaseTokensMinted {
        // Arrange
        vm.startPrank(user);
        rebaseToken.approve(owner, AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 recipientBalanceBefore = rebaseToken.balanceOf(recipient);

        // Act
        vm.startPrank(owner);
        bool success = rebaseToken.transferFrom(user, recipient, type(uint256).max);
        vm.stopPrank();

        // Assert
        assertEq(recipientBalanceBefore, 0, "Recipient initial balance should be zero.");
        assertTrue(success, "Transfer failed.");

        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        uint256 recipientBalanceAfter = rebaseToken.balanceOf(recipient);

        assertEq(userBalanceAfter, 0, "User balance should be 0.");
        assertEq(recipientBalanceAfter, AMOUNT_TO_MINT, "Recipient balance should equal to amount minted.");
        assertEq(
            rebaseToken.getUserInterestRate(recipient),
            rebaseToken.getUserInterestRate(user),
            "Recipient interest rate should match user's."
        );
    }

    /*//////////////////////////////////////////////////////////////
                      mintAccruedInterest Tests
    //////////////////////////////////////////////////////////////*/

    function test_MintAccruedInterest() public {
        // Arrange
        vm.startPrank(owner);
        rebaseTokenHarness = new RebasePwjTokenHarness();
        rebaseTokenHarness.grantMintAndBurnRole(address(vault));
        vm.stopPrank();

        uint256 userInterestRate = rebaseToken.getGlobalInterestRate();
        vm.startPrank(address(vault));
        rebaseTokenHarness.mint(user, AMOUNT_TO_MINT, userInterestRate);
        vm.stopPrank();

        uint256 principalBefore = rebaseTokenHarness.getPrincipalBalanceOf(user);

        vm.warp(block.timestamp + 1 hours);
        uint256 accruedBalance = rebaseTokenHarness.balanceOf(user);

        // Act
        vm.startPrank(owner);
        rebaseTokenHarness.exposed_MintAccruedInterest(user);
        vm.stopPrank();

        // Assert
        assertEq(principalBefore, AMOUNT_TO_MINT, "Initial principal balance should equal minted amount.");
        assertGt(accruedBalance, principalBefore, "Accrued balance should exceed principal after time warp.");

        uint256 principalAfter = rebaseTokenHarness.getPrincipalBalanceOf(user);
        uint256 finalBalance = rebaseTokenHarness.balanceOf(user);
        assertEq(principalAfter, finalBalance, "Principal balance should be updated to equal the accrued balance.");

        uint256 mintedInterest = principalAfter - principalBefore;
        uint256 expectedInterest = accruedBalance - principalBefore;
        assertEq(mintedInterest, expectedInterest, "Minted interest should equal the accrued difference.");

        uint256 lastUpdated = rebaseTokenHarness.getUserLastUpdatedTimestamp(user);
        assertEq(lastUpdated, block.timestamp, "User last updated timestamp should equal current block time.");
    }

    /*//////////////////////////////////////////////////////////////
        calculateUserAccumulatedInterestSinceLastUpdate Tests
    //////////////////////////////////////////////////////////////*/

    function test_CalculateAccumulatedInterest() public {
        // Arrange
        vm.startPrank(owner);
        rebaseTokenHarness = new RebasePwjTokenHarness();
        rebaseTokenHarness.grantMintAndBurnRole(address(vault));
        vm.stopPrank();

        uint256 userInterestRate = rebaseTokenHarness.getUserInterestRate(user);

        vm.startPrank(address(vault));
        rebaseTokenHarness.mint(user, AMOUNT_TO_MINT, userInterestRate);
        vm.stopPrank();

        uint256 lastUpdated = rebaseTokenHarness.getUserLastUpdatedTimestamp(user);
        vm.warp(lastUpdated + 1 hours);

        // Act
        uint256 multiplier = rebaseTokenHarness.exposed_CalculateAccumulatedInterest(user);

        // Assert
        uint256 precision = rebaseTokenHarness.getPrecisionFactor();
        uint256 expectedMultiplier = precision + (userInterestRate * 1 hours);

        assertEq(
            multiplier,
            expectedMultiplier,
            "The calculated accrued interest multiplier should equal to expected multiplier."
        );
    }
}
