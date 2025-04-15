// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VTokenBase} from "./VTokenBase.sol";

contract vGLMR is VTokenBase {
    function initialize(IERC20 asset, address owner) public initializer {
        __VTokenBase_init(asset, owner, "Bifrost Voucher GLMR", "vGLMR");
    }
}
