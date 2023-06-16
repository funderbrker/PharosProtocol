// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library C {
    uint256 internal constant ETH_DECIMALS = 18;

    uint256 internal constant RATIO_FACTOR = 1e18;
    uint256 internal constant OWNERSHIP_BASE = 1e18;

    uint256 internal constant SECS_IN_HOUR = 3600;

    address internal constant MODULEND_ADDR = address(0x1);

    address internal constant UNI_V2_ROUTER02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address internal constant UNI_V3_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address internal constant UNI_V3_POOL_USDC_ETH = address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    uint32 internal constant CURVE_VALUATOR_TYPE_ID = 1;

    // MAINNET ADDRESSES
    address internal constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // GOERLI ADDRESSES
    // address internal constant USDC = address(0x32dBd8db20Bfe5506104119EdCC89bc3D8C5c3Ee);
    // address internal constant WETH = address(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    bytes32 internal constant BOOKKEEPER_ROLE = keccak256("BOOKKEEPER_ROLE");
    bytes32 internal constant ADMIN_ROLE = 0x00;
}