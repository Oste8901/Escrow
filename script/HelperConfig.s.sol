//SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activenetworkconfig;

    constructor() {
        if (block.chainid == 11155111) {
            activenetworkconfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activenetworkconfig = getMainnetEthConfig();
        } else {
            activenetworkconfig = getAnvilEthConfig();
        }
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory localNetworkConfig) {
        ERC20Mock wethMock = new ERC20Mock();
        ERC20Mock wbtcMock = new ERC20Mock();
        localNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(1),
            wbtcUsdPriceFeed: address(2),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: 0
        });
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: address(0), // The Sepolia demo supports WETH only.
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return sepoliaNetworkConfig;
    }

    function getMainnetEthConfig() public view returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // ETH / USD
            wbtcUsdPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, // BTC / USD
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return mainnetNetworkConfig;
    }
}
