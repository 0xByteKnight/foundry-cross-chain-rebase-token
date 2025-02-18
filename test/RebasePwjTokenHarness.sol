// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasePwjToken} from "src/RebasePwjToken.sol";

contract RebasePwjTokenHarness is RebasePwjToken {
    function exposed_MintAccruedInterest(address _user) external {
        _mintAccruedInterest(_user);
    }

    function exposed_CalculateAccumulatedInterest(address _user) external view returns (uint256) {
        return _calculateUserAccumulatedInterestSinceLastUpdate(_user);
    }
}
