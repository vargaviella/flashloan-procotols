// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "IFlashLoanRecipient.sol";
import "IBalancerVault.sol";
import "hardhat/console.sol";

pragma solidity ^0.8.0;

interface CORE{
    function liquidate(address borrower,address pool,address collateral,uint256 debtAmount) external;
}

interface WETH {
    function approve(address guy, uint wad) external;
    function balanceOf(address) external returns(uint256);
}

interface USDC {
    function approve(address spender, uint value) external;
    function balanceOf(address account) external returns(uint256);
}

interface ROUTER {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


contract BalancerFlashLoan is IFlashLoanRecipient {
    using SafeMath for uint256;

    address public immutable vaultContractAddress = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address private owner;
    address public coreContractAddress = 0x1522aD0a3250eb0F64E0ACfe090CA40949330Cc1;
    address public poolContractAddress = 0xD82d7300e5d3b3db85594E9171Af9d58d6628366;
    address public collateralContractAddress = 0xDb7869Ffb1E46DD86746eA7403fa2Bb5Caf7FA46;
    address public wethContractAddress = 0x4200000000000000000000000000000000000006;
    address public usdcContractAddress = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public routerContractAddress = 0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891;

    constructor() {
        owner = msg.sender;
    }


    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    receive() external payable {
}

    function uno() public {
        USDC usdc = USDC(usdcContractAddress);
        CORE core = CORE(coreContractAddress);
        WETH weth = WETH(wethContractAddress);

        usdc.approve(address(this), 100000000);
        usdc.approve(vaultContractAddress, 100000000);
        usdc.approve(collateralContractAddress, 100000000);
        usdc.approve(poolContractAddress, 100000000);
        usdc.approve(coreContractAddress, 100000000);

        weth.approve(address(this), 1000000000000000000000);
        weth.approve(coreContractAddress, 1000000000000000000000);

        core.liquidate(0xf9c12c37269EF3De90E5830EE10508eA20079b04,
        poolContractAddress,
        collateralContractAddress,
        10000000);
    }

    function dos() public {
        USDC usdc = USDC(usdcContractAddress);
        ROUTER router = ROUTER(routerContractAddress);
        WETH weth = WETH(wethContractAddress);

        weth.approve(address(this), weth.balanceOf(address(this)));
        weth.approve(routerContractAddress, weth.balanceOf(address(this)));

        usdc.approve(address(this), 10000000000);
        usdc.approve(routerContractAddress, 10000000000);
        usdc.approve(vaultContractAddress, 10000000000);

        uint256 deadline = block.timestamp + 1 hours;
        
        // Crear el array de direcciones para el path
        address[] memory path = new address[](2);
        path[0] = wethContractAddress;
        path[1] = usdcContractAddress;

        require(path.length == 2, "Invalid path length");
        
        // Llamar a la función de swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            weth.balanceOf(address(this)),
            1,
            path,
            address(this),
            deadline
        );
    }


    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external override {
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];
            console.log("borrowed amount:", amount);
            uint256 feeAmount = feeAmounts[i];
            console.log("flashloan fee: ", feeAmount);

            uno();
            dos();

            // Return loan
            token.transfer(vaultContractAddress, amount);
        }
    }

    function flashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) public {
        IBalancerVault(vaultContractAddress).flashLoan(
            IFlashLoanRecipient(address(this)),
            tokens,
            amounts,
            userData
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
}
