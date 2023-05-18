// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/LibUtil.sol";
import {C} from "src/C.sol";

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccount} from "src/modules/account/IAccount.sol";
import {Module} from "src/modules/Module.sol";

/**
 * Account for holding ETH and ERC20 assets, to use for either lending or borrowing through an Agreement.
 * ~ Not compatible with other asset types ~
 */
contract DoubleSidedAccount is AccessControl, IAccount, Module {
    struct Parameters {
        address owner;
        // An owner-unique id for this account.
        bytes32 salt;
    }

    event AssetLoaded(Asset indexed asset, uint256 amount, Parameters indexed parameters);
    event AssetUnloaded(Asset indexed asset, uint256 amount, Parameters indexed parameters);
    event PositionCapitalized(address indexed position, Asset indexed asset, uint256 amount, bytes indexed parameters);

    address immutable _this;
    mapping(bytes32 => mapping(bytes32 => uint256)) private accounts; // account id => asset hash => amount

    constructor(address bookkeeperAddr) {
        _grantRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
        _this = address(this);

        COMPATIBLE_LOAN_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
        COMPATIBLE_COLL_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
    }

    receive() external payable {}

    function load(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        _increaseBalance(asset, amount, params);
        require(IERC20(asset.addr).transferFrom(msg.sender, address(this), amount), "ERC20 transfer failed");
    }

    /// @dev the bookkeeper is the only actor that is allowed to act as a delegate. Else approved funds are at risk.
    function sideLoad(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        payable
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        _increaseBalance(asset, amount, params);
        require(IERC20(asset.addr).transferFrom(from, address(this), amount), "ERC20 transfer failed");
    }

    // NOTE should check compatibility in each function?
    function loadPush(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable override {
        require(address(this) != _this, "loadPush: must be delegatecall");
        Parameters memory params = abi.decode(parameters, (Parameters));
        _increaseBalance(asset, amount, params);
        if (asset.standard == ETH_STANDARD) {
            // NOTE yes yes someday the gas may become invalid. But simplest way to start.
            payable(_this).transfer(amount);
        } else if (asset.standard == ERC20_STANDARD) {
            // IERC20 memory erc20 = IERC20(asset.addr);
            // erc20.approve(amount);
            IERC20(asset.addr).transfer(_this, amount);
        }
    }

    // // Use callback. Allows for 3rdparty transferFroms without extra transfers.
    // function loadPushFrom(address from, Asset calldata asset, uint256 amount, bytes calldata parameters) external payable override {
    // }

    // function throughPushWithCallback(address to, Asset calldata asset, uint256 amount) {}

    function unload(Asset calldata asset, uint256 amount, bytes calldata parameters) external override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        require(msg.sender == params.owner, "unload: not owner");
        _decreaseBalance(asset, amount, params);
        Utils.sendAsset(msg.sender, asset, amount); // ETH and ERC20 implemented
    }

    /// @dev if supporting ETH, will receive directly as msg.value and msg.sender may differ from from parameter.
    /// @dev revert if all assets amount not transferred successfully.
    function _increaseBalance(Asset calldata asset, uint256 amount, Parameters memory params) private {
        accounts[_getId(params.owner, params.salt)][keccak256(abi.encode(asset))] += amount;
        emit AssetLoaded(asset, amount, params);
    }

    function _decreaseBalance(Asset calldata asset, uint256 amount, Parameters memory params) private {
        accounts[_getId(params.owner, params.salt)][keccak256(abi.encode(asset))] -= amount;
        emit AssetUnloaded(asset, amount, params);
    }

    // NOTE could bypass need hre (and other modules) for C.BOOKKEEPER_ROLE by verifying signed agreement and tracking
    //      which have already been processed.
    function capitalize(address position, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        accounts[id][keccak256(abi.encode(asset))] -= amount;
        require(IERC20(asset.addr).transfer(position, amount), "capitalize: ERC20 transfer failed");

        emit PositionCapitalized(position, asset, amount, parameters);
    }

    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
    }

    function getBalance(Asset calldata asset, bytes calldata parameters)
        external
        view
        override
        returns (uint256 amounts)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 accountId = _getId(params.owner, params.salt);
        return accounts[accountId][keccak256(abi.encode(asset))];
    }

    function _getId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
