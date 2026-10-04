// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployEscrow} from "../script/DeployEscrow.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Escrow} from "../src/Escrow.sol";
import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract EscrowTest is Test {
    address weth_p_usd;
    address weth_;
    address wbtc;
    address[] token_add;
    address[] token_p;
    uint256 constant Test_Client_Balance = 200 ether;
    uint256 constant Test_Payment_Amount = 100 ether;
    address CLIENT = makeAddr("client");
    address client = makeAddr("Client");
    address EMPLOYEE = makeAddr("employee");
    address employee = makeAddr("Employee");
    HelperConfig config;
    DeployEscrow deploy;
    Escrow es_;

    function setUp() public {
        deploy = new DeployEscrow();
        (config, es_) = deploy.run();
        (weth_p_usd,, weth_, wbtc,) = config.activenetworkconfig();
        ERC20Mock(weth_).mint(CLIENT, Test_Client_Balance);
    }

    function testReverts_LenghtMisMatch() public {
        token_add.push(weth_);
        token_add.push(wbtc);
        token_p.push(weth_p_usd);
        vm.expectRevert();
        new Escrow(token_add, token_p);
    }

    function testCreateEscrow_Works() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        uint256 contract_balance_before = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 client_balance_before = ERC20Mock(weth_).balanceOf(CLIENT);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        uint256 contract_balance_after = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 client_balance_after = ERC20Mock(weth_).balanceOf(CLIENT);
        assert(contract_balance_before + Test_Payment_Amount == contract_balance_after);
        assert(client_balance_before - Test_Payment_Amount == client_balance_after);
        assert(CLIENT == es_.retrieve_Client(0));
        assert(EMPLOYEE == es_.retrieve_Freelancer(0));
        vm.stopPrank();
    }

    function testGetSupportedTokens() public view {
        address[] memory supportedTokens = es_.getSupportedTokens();

        assertEq(supportedTokens.length, 2);
        assertEq(supportedTokens[0], weth_);
        assertEq(supportedTokens[1], wbtc);
    }

    function testReleaseFundsReverts() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        es_.raiseDispute(0);
        vm.expectRevert();
        es_.releaseFunds(0);
        vm.stopPrank();
    }

    function testReleasFunds() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        uint256 holder_f_balance = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 employee_f_balance = ERC20Mock(weth_).balanceOf(EMPLOYEE);
        es_.releaseFunds(0);
        uint256 holder_s_balance = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 employee_s_balance = ERC20Mock(weth_).balanceOf(EMPLOYEE);
        assert(holder_f_balance - Test_Payment_Amount == holder_s_balance);
        assert(employee_f_balance + Test_Payment_Amount == employee_s_balance);
        assert(es_.retrieve_status(0) == Escrow.Status.Completed);
        vm.stopPrank();
    }

    function testRaiseDispute_fails() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        vm.stopPrank();
        vm.startPrank(client);
        vm.expectRevert();
        es_.raiseDispute(0);
    }

    function testRaiseDispute_fails_Employee() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        vm.stopPrank();
        vm.startPrank(employee);
        vm.expectRevert();
        es_.raiseDispute(0);
    }

    function testRaiseDispute() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        es_.raiseDispute(0);
        assert(es_.retrieve_status(0) == Escrow.Status.Disputed);
        vm.stopPrank();
    }

    function testResolveDispute_fails() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        vm.stopPrank();
        vm.startPrank(es_.retrieve_owner());
        vm.expectRevert();
        es_.resolveDispute(0, CLIENT);
        vm.stopPrank();
    }

    function testResolveDispute_fails_() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        es_.raiseDispute(0);
        vm.expectRevert();
        es_.resolveDispute(0, CLIENT);
        vm.stopPrank();
    }

    function testResolveDispute_Client() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        es_.raiseDispute(0);
        vm.stopPrank();
        uint256 holder_fi_balance = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 client_fi_balance = ERC20Mock(weth_).balanceOf(CLIENT);
        vm.startPrank(es_.retrieve_owner());
        es_.resolveDispute(0, CLIENT);
        uint256 holder_ = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 client_e = ERC20Mock(weth_).balanceOf(CLIENT);
        assert(holder_fi_balance - Test_Payment_Amount == holder_);
        assert(client_fi_balance + Test_Payment_Amount == client_e);
        assert(es_.retrieve_status(0) == Escrow.Status.Completed);
        vm.stopPrank();
    }

    function testResolveDispute_Employee() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        es_.raiseDispute(0);
        vm.stopPrank();
        uint256 holder_fi_balance = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 _fi_balance = ERC20Mock(weth_).balanceOf(EMPLOYEE);
        vm.startPrank(es_.retrieve_owner());
        es_.resolveDispute(0, EMPLOYEE);
        uint256 holder_ = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 _e = ERC20Mock(weth_).balanceOf(EMPLOYEE);
        assert(holder_fi_balance - Test_Payment_Amount == holder_);
        assert(_fi_balance + Test_Payment_Amount == _e);
        assert(es_.retrieve_status(0) == Escrow.Status.Completed);
        vm.stopPrank();
    }

    function testCancelEscrow_Fails() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        vm.stopPrank();
        vm.startPrank(client);
        vm.expectRevert();
        es_.cancelEscrow(0);
        vm.stopPrank();
    }

    function testCancelEscrow() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        uint256 the_holder = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 cl_ = ERC20Mock(weth_).balanceOf(CLIENT);
        es_.cancelEscrow(0);
        uint256 the_hold = ERC20Mock(weth_).balanceOf(address(es_));
        uint256 cl = ERC20Mock(weth_).balanceOf(CLIENT);
        assert(the_holder - Test_Payment_Amount == the_hold);
        assert(cl_ + Test_Payment_Amount == cl);
        assert(es_.retrieve_status(0) == Escrow.Status.Cancelled);
        vm.stopPrank();
    }

    function testCancelEscrow_failsStatus() public {
        vm.startPrank(CLIENT);
        ERC20Mock(weth_).approve(address(es_), Test_Payment_Amount);
        es_.createEscrow(EMPLOYEE, weth_, Test_Payment_Amount);
        es_.raiseDispute(0);
        vm.expectRevert();
        es_.cancelEscrow(0);
        vm.stopPrank();
    }
}
