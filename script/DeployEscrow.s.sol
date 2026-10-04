//SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";
import {Escrow} from "../src/Escrow.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployEscrow is Script {
    address[] pricefeed;
    address[] tokens_;

    function run() external returns (HelperConfig, Escrow) {
        HelperConfig config;
        address wethusd;
        address wbtcusd;
        address weth;
        address wbtc;
        uint256 deployerKey;

        if (block.chainid == 11155111 || block.chainid == 1) {
            config = new HelperConfig();
            (wethusd, wbtcusd, weth, wbtc, deployerKey) = config.activenetworkconfig();
            vm.startBroadcast(deployerKey);
            if (block.chainid == 11155111) {
                wbtc = address(new ERC20Mock());
            }
        } else {
            vm.startBroadcast();
            config = new HelperConfig();
            (wethusd, wbtcusd, weth, wbtc, deployerKey) = config.activenetworkconfig();
        }

        pricefeed = [wethusd, wbtcusd];
        tokens_ = [weth, wbtc];
        Escrow es_c = new Escrow(tokens_, pricefeed);
        vm.stopBroadcast();

        console2.log("Escrow deployed at:", address(es_c));
        console2.log("Network chain ID:", block.chainid);
        console2.log("Supported token 0:", weth);
        console2.log("Supported token 1:", wbtc);

        return (config, es_c);
    }
}
