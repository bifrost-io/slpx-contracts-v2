// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {VTokenBase} from "./VTokenBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VToken is VTokenBase {
    function initialize(IERC20 asset, address owner, string memory name, string memory symbol) public initializer {
        __VTokenBase_init(asset, owner, name, symbol);
    }
}
