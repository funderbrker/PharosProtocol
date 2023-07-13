// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtils.sol";
import {CloneFactory} from "src/plugins/CloneFactory.sol";

abstract contract Position is IPosition, CloneFactory {
    event ControlTransferred(address previousController, address newController);

    constructor(address bookkeeperAddr) CloneFactory(bookkeeperAddr) {
        // _setupRole
        // _setupRole
    }

    function deploy(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        _deploy(asset, amount, parameters);
    }

    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    function close(
        address sender,
        Agreement calldata agreement
    ) external override proxyExecution onlyRole(C.ADMIN_ROLE) returns (uint256) {
        return _close(sender, agreement);
    }

    function distribute(
        address sender,
        uint256 lenderAmount,
        Agreement calldata agreement
    ) external payable override proxyExecution onlyRole(C.ADMIN_ROLE) {
        return _distribute(sender, lenderAmount, agreement);
    }

    function getCloseAmount(bytes calldata parameters) external view override proxyExecution returns (uint256) {
        return _getCloseAmount(parameters);
    }

    /// @notice Close position and distribute assets. Give borrower MPC control.
    /// @dev All asset management must be done within this call, else bk would need to have asset-specific knowledge.
    function _close(address sender, Agreement calldata agreement) internal virtual returns (uint256);

    function _distribute(address sender, uint256 lenderAmount, Agreement calldata agreement) internal virtual;

    function _getCloseAmount(bytes calldata parameters) internal view virtual returns (uint256);

    // SECURITY Hello auditors. This feels risky.
    function transferContract(address controller) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        // ADMIN_ROLE is not transferred to prevent hostile actors from 'reactivating' a position by setting the
        // controller back to the bookkeeper.
        // grantRole(LIQUIDATOR_ROLE, controller); // having a distinct liquidator role and controller role is a nicer abstraction, but has gas cost for no benefit.
        grantRole(C.ADMIN_ROLE, controller);
        renounceRole(C.ADMIN_ROLE, msg.sender);

        // TODO fix this so that admin role is not granted to untrustable code (liquidator user or plugin). Currently
        // will get stuck as liquidator plugin will not be able to grant liquidator control.
        // Do not allow liquidators admin access to avoid security implications if set back to protocol control.
        // if (grantAdmin) {
        //     grantRole(DEFAULT_ADMIN_ROLE, controller);
        // }
        // renounceRole(DEFAULT_ADMIN_ROLE);
        emit ControlTransferred(msg.sender, controller);
    }

    function passThrough(
        address payable destination,
        bytes calldata data,
        bool delegateCall
    ) external payable proxyExecution onlyRole(C.ADMIN_ROLE) returns (bool, bytes memory) {
        if (!delegateCall) {
            return destination.call{value: msg.value}(data);
        } else {
            return destination.delegatecall(data);
        }
    }
}