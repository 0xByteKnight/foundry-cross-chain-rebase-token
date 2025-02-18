// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {RebasePwjToken} from "src/RebasePwjToken.sol";
import {RebasePwjTokenPool} from "src/RebasePwjTokenPool.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract DeployTokenAndPool is Script {
    function run()
        public
        returns (RebasePwjToken token, RebasePwjTokenPool pool, Register.NetworkDetails memory networkDetails)
    {
        CCIPLocalSimulatorFork localSimulatorFork = new CCIPLocalSimulatorFork();
        networkDetails = localSimulatorFork.getNetworkDetails(block.chainid);

        vm.startBroadcast();
        token = new RebasePwjToken();
        pool = new RebasePwjTokenPool(
            IERC20(address(token)), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );
        token.grantMintAndBurnRole(address(pool));

        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(token), address(pool));
        vm.stopBroadcast();
    }
}

contract DeployVault is Script {
    function run(address rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(rebaseToken));
        IRebaseToken(rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
