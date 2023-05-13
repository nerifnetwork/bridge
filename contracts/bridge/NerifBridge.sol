// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/INerifBridgeReceiver.sol";

// NerifBridge is the simple bridging contract needed to run Nerif Bridge.
// The contract contains VERY LIMITED FUNCTIONALITY and CANNOT BY USED FOR PRODUCTION PURPOSES.
// The logic does not contain a proper security setup as well as billing mechanis
// and many other things needed for commercial production use.
contract NerifBridge is Initializable, Ownable {
    mapping(address => bool) public senders;
    address public gateway;
    uint256 public fee;

    event Send(uint256 chainId, address target, bytes payload, uint256 gasAmount, address sender);
    event Receive(address target, bytes payload, uint256 gasAmount);
    event RewardsWithdrawn(uint256 amount);

    // onlySenders permits sending transactions to whitelisted addresses only.
    // This restriction is completely optional acn can be removed.
    modifier onlySenders() {
        require(senders[msg.sender], "Bridge: only allowed sender");
        _;
    }

    // onlyGateway permits transactions coming from the Nerif Network Gateway contract.
    modifier onlyGateway() {
        require(gateway == msg.sender, "Bridge: only gateway");
        _;
    }

    // initialize initializes the contract with all required parameters.
    function initialize(
        address[] calldata _senders,
        address _gateway,
        uint256 _fee
    ) external initializer {
        for (uint256 i = 0; i < _senders.length; i++) {
            senders[_senders[i]] = true;
        }

        setGateway(_gateway);
        setFee(_fee);
    }

    // withdrawRewards sends network rewards to the rewards withdrawal address
    function withdraw() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "balance: nothing to withdraw");

        address payable owner = payable(owner());

        // Transfer rewards
        owner.transfer(balance);

        // Emit an event to log the withdrawal transaction
        emit RewardsWithdrawn(balance);
    }

    // send sends message to other contract on the specified chain.
    function send(
        uint256 chainId,
        address target,
        bytes calldata payload,
        uint256 gasAmount
    ) external payable onlySenders {
        // Must give fee
        require(msg.value == fee, "NerifBridge: no fee provided");

        // This event triggers Nerif Network workflow execution.
        // The workflow receives the event payload and
        // passes it to the bridge contract on the targeted chain.
        emit Send(chainId, target, payload, gasAmount, msg.sender);
    }

    // rec receives messages from other chains using Nerif Bridge.
    function rec(
        uint256 chainId,
        address target,
        bytes calldata payload,
        uint256 gasAmount,
        address sender
    ) external onlyGateway {
        // Send the given payload to the receiver contract.
        INerifBridgeReceiver(target).nbReceive{gas: gasAmount}(chainId, sender, payload);

        // Here you can add any other kind of logic depending on the business requirements
        // such as billing mechanism, security checks, etc.
        // Most of them could be powered by Nerif Network as well.

        emit Receive(target, payload, gasAmount);
    }

    // addSender adds the given message sender to the whitelist so it can send messages.
    function addSender(address sender) external onlyOwner {
        senders[sender] = true;
    }

    // removeSender removes the given sender from the whitelist.
    function removeSender(address sender) external onlyOwner {
        delete senders[sender];
    }

    // setGateway updates the gateway address.
    function setGateway(address _gateway) public onlyOwner {
        gateway = _gateway;
    }

    // setFee updates the bridge fee.
    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }
}
