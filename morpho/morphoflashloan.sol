// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
import "IMorphoCallbacks.sol";
import "IMorpho.sol";

interface WETH {
    function balanceOf(address) external view returns (uint256);
    function approve(address guy, uint256 wad) external;
}

contract FlashBorrowerMock is IMorphoFlashLoanCallback {
    using SafeMath for uint256;
    
    address private immutable morphoContractAddress = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address private owner;
    address public wethContractAddress = 0x4200000000000000000000000000000000000006;

    event FlashLoanReceived(uint256 assets, address token);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function flashLoan(address token, uint256 assets, bytes memory data) external {
        IMorpho(morphoContractAddress).flashLoan(token, assets, data);
    }

    function onMorphoFlashLoan(uint256 assets, bytes memory data) external override {
        require(msg.sender == morphoContractAddress, "Unauthorized sender");

        WETH weth = WETH(wethContractAddress);

        weth.approve(address(this), assets);
        weth.approve(morphoContractAddress, assets);
        
    }

    function withdrawTokens(IERC20[] memory tokens, uint256[] memory amounts) external onlyOwner {
        require(tokens.length == amounts.length, "Token and amount arrays must have the same length");

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = tokens[i].balanceOf(address(this));
            require(balance >= amounts[i], "Insufficient token balance");

            tokens[i].transfer(msg.sender, amounts[i]);
        }
    }

    function withdrawEther(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient Ether balance");
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        // Allows the contract to receive Ether
    }
}
