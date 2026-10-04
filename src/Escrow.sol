//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract Escrow {
    error TokenAndPriceFeedLengthMismatch();
    error NotOwner();
    error TokenNotValid();
    error TransferFailed();
    error Not_Escrow_Client();
    error Escrow_NotActive();
    error Not_In_Escrow();

    enum Status {
        Active,
        Disputed,
        Completed,
        Cancelled
    }

    struct EscrowDetails {
        address client;
        address freelancer;
        address token;
        uint256 amount;
        Status status;
        bool is_initialized;
    }

    mapping(address => address) public pricefeed;
    mapping(address => uint256) public dep_amt;

    address public owner;
    uint256 public escrow_id;
    address[] public tokens_;
    EscrowDetails[] public escrows;

    constructor(address[] memory token_addr, address[] memory price_feed_addr) {
        owner = msg.sender;
        escrow_id = 0;

        if (token_addr.length != price_feed_addr.length) {
            revert TokenAndPriceFeedLengthMismatch();
        }
        for (uint256 i = 0; i < token_addr.length; ++i) {
            pricefeed[token_addr[i]] = price_feed_addr[i];
            tokens_.push(token_addr[i]);
        }
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    modifier isTokenAllowed(address tok) {
        if (pricefeed[tok] == address(0)) {
            revert TokenNotValid();
        }
        _;
    }

    function createEscrow(address _freelancer, address _token, uint256 _amount) public isTokenAllowed(_token) {
        escrows.push(EscrowDetails(msg.sender, _freelancer, _token, _amount, Status.Active, true));
        dep_amt[msg.sender] += _amount;
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert TransferFailed();
        }
        escrow_id++;
    }

    function releaseFunds(uint256 esc_id) public {
        EscrowDetails storage escrow_ = escrows[esc_id];
        if (msg.sender != escrow_.client) {
            revert Not_Escrow_Client();
        }

        if (escrow_.status != Status.Active) {
            revert Escrow_NotActive();
        }

        dep_amt[escrow_.client] -= escrow_.amount;
        bool is_success = IERC20(escrow_.token).transfer(escrow_.freelancer, escrow_.amount);
        if (!is_success) {
            revert TransferFailed();
        }
        escrow_.status = Status.Completed;
    }

    function raiseDispute(uint256 es_id) public {
        EscrowDetails storage es = escrows[es_id];
        if (msg.sender == es.client || msg.sender == es.freelancer) {
            require(es.status == Status.Active, "Escrow is not active");
            es.status = Status.Disputed;
        } else {
            revert Not_In_Escrow();
        }
    }

    function resolveDispute(uint256 esc_id, address winner) public onlyOwner {
        EscrowDetails storage escrow_es = escrows[esc_id];
        require(escrow_es.status == Status.Disputed, "No Dispute");
        uint256 amount = escrow_es.amount;
        if (winner == escrow_es.client) {
            dep_amt[escrow_es.client] -= amount;
            bool transfer_success = IERC20(escrow_es.token).transfer(escrow_es.client, amount);
            if (!transfer_success) {
                revert TransferFailed();
            }
        } else if (winner == escrow_es.freelancer) {
            dep_amt[escrow_es.client] -= amount;
            bool is_success = IERC20(escrow_es.token).transfer(escrow_es.freelancer, amount);
            if (!is_success) {
                revert TransferFailed();
            }
        }

        escrow_es.status = Status.Completed;
    }

    function cancelEscrow(uint256 job_id) public {
        EscrowDetails storage es_crow = escrows[job_id];
        if (msg.sender != es_crow.client) {
            revert Not_Escrow_Client();
        }
        if (es_crow.status != Status.Active) {
            revert Escrow_NotActive();
        }
        dep_amt[es_crow.client] -= es_crow.amount;
        bool the_transfer = IERC20(es_crow.token).transfer(es_crow.client, es_crow.amount);
        if (!the_transfer) {
            revert TransferFailed();
        }
        es_crow.status = Status.Cancelled;
    }

    function retrieve_Client(uint256 ret_id) public view returns (address) {
        EscrowDetails storage esc_row_ = escrows[ret_id];
        return esc_row_.client;
    }

    function retrieve_Freelancer(uint256 re_id) public view returns (address) {
        EscrowDetails storage esc_ret = escrows[re_id];
        return esc_ret.freelancer;
    }

    function retrieve_status(uint256 retid) public view returns (Status) {
        EscrowDetails storage the_es_crow = escrows[retid];
        return the_es_crow.status;
    }

    function retrieve_(uint256 retid) public view returns (EscrowDetails memory the_es_cro) {
        the_es_cro = escrows[retid];
        return the_es_cro;
    }

    function retrieve_owner() public view returns (address) {
        return owner;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return tokens_;
    }
}
