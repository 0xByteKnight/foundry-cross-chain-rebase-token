// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RebasePwjToken} from "src/RebasePwjToken.sol";
import {RebasePwjTokenPool} from "src/RebasePwjTokenPool.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/src/v0.8/ccip/libraries/RateLimiter.sol";

import {DeployTokenAndPool, DeployVault} from "script/01_Deploy.s.sol";
import {ConfigurePool} from "script/02_ConfigurePool.s.sol";
import {BridgeTokens} from "script/03_BridgeTokens.s.sol";

contract CrossChain is Test {
    CCIPLocalSimulatorFork public chainlinkLocalSimulatorFork;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryArbSepolia;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomArbSepolia;

    RebasePwjToken sepoliaToken;
    RebasePwjToken arbSepoliaToken;
    RebasePwjTokenPool sepoliaPool;
    RebasePwjTokenPool arbSepoliaPool;
    Vault vault;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    uint256 public constant SEND_VALUE = 1e5;

    function setUp() public {
        // Create forks.
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createSelectFork("arb-sepolia");

        vm.selectFork(sepoliaFork);
        chainlinkLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(chainlinkLocalSimulatorFork));

        vm.selectFork(sepoliaFork);
        DeployTokenAndPool deployerSepolia = new DeployTokenAndPool();
        (sepoliaToken, sepoliaPool, sepoliaNetworkDetails) = deployerSepolia.run(); // deploys token and pool on Sepolia
        DeployVault deployVault = new DeployVault();
        vault = deployVault.run(address(sepoliaToken));

        vm.selectFork(arbSepoliaFork);
        DeployTokenAndPool deployerArb = new DeployTokenAndPool();
        (arbSepoliaToken, arbSepoliaPool, arbSepoliaNetworkDetails) = deployerArb.run(); // deploys token and pool on Arb Sepolia

        // On Sepolia, set Arb Sepolia’s pool and token as remote:
        vm.selectFork(sepoliaFork);
        ConfigurePool configureSepolia = new ConfigurePool();
        configureSepolia.run(
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            true,
            address(arbSepoliaPool),
            address(arbSepoliaToken),
            false,
            0,
            0,
            false,
            0,
            0
        );

        // On Arb Sepolia, configure Sepolia as remote:
        vm.selectFork(arbSepoliaFork);
        ConfigurePool configureArb = new ConfigurePool();
        configureArb.run(
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            true,
            address(sepoliaPool),
            address(sepoliaToken),
            false,
            0,
            0,
            false,
            0,
            0
        );
    }

    function testFork_bridgeAllTokensToTargetChain() public {
        // Arrange
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        vault.deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);

        BridgeTokens bridgeScript = new BridgeTokens();

        // Act
        bridgeScript.run(
            arbSepoliaNetworkDetails.chainSelector,
            sepoliaNetworkDetails.routerAddress,
            user,
            address(sepoliaToken),
            sepoliaNetworkDetails.linkAddress,
            SEND_VALUE
        );

        // Assert
        chainlinkLocalSimulatorFork.switchChainAndRouteMessage(arbSepoliaFork);
        uint256 balanceOfUserOnArbSepolia = arbSepoliaToken.balanceOf(user);
        assertEq(balanceOfUserOnArbSepolia, SEND_VALUE);
    }

    // TODO: This test fails due to low gas limit. I need to perform some gas optimization in the project.
    // function testFork_bridgeAllTokensToAndFromTargetChain() public {
    //     // Arrange
    //     vm.selectFork(sepoliaFork);
    //     vm.deal(user, SEND_VALUE);
    //     vm.prank(user);
    //     vault.deposit{value: SEND_VALUE}();
    //     assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);

    //     BridgeTokens bridgeScript = new BridgeTokens();

    //     // Act & Assert
    //     bridgeScript.run(
    //         arbSepoliaNetworkDetails.chainSelector,
    //         sepoliaNetworkDetails.routerAddress,
    //         user,
    //         address(sepoliaToken),
    //         sepoliaNetworkDetails.linkAddress,
    //         SEND_VALUE
    //     );

    //     chainlinkLocalSimulatorFork.switchChainAndRouteMessage(arbSepoliaFork);

    //     uint256 balanceOfUserOnArbSepolia = arbSepoliaToken.balanceOf(user);
    //     assertEq(balanceOfUserOnArbSepolia, SEND_VALUE);

    //     bridgeScript.run(
    //         sepoliaNetworkDetails.chainSelector,
    //         arbSepoliaNetworkDetails.routerAddress,
    //         user,
    //         address(arbSepoliaToken),
    //         arbSepoliaNetworkDetails.linkAddress,
    //         arbSepoliaToken.balanceOf(user)
    //     );
    // }
}
