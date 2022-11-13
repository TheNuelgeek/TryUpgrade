// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IBridgeFee.sol";
import "./interfaces/IAnyswapRouter.sol";
import "hardhat/console.sol";

/// @title Bridge Fee
/// @notice This contract is the middleware of MadWallet fee system and the AnySwap bridge contract
contract BridgeFee is Initializable, IBridgeFee {
    /// @notice the default fee percentage of bridging tokens
    Fee public defaultFee;

    address private _owner;

    /// @notice stores the address that will receive the fee
    address public feeAddress;

    /// @notice stores the fee per token
    mapping(address => Fee) public tokenFee;

    event OwnershipTransferred(address oldOwner, address newOwner);
    event BridgeDone(
        address indexed sender,
        address indexed dcrmAddress,
        address indexed tokenAddress,
        uint256 amount,
        uint256 feeAmount
    );

    modifier onlyOwner () {
        require(owner() == msg.sender, "caller is not the owner");
        _;
    }

    function initialize() public initializer {
        _owner = msg.sender;
    }

    /// @notice A function to set the primary contract state variables
    /// @param _feeAddress the value for feeAddress
    /// @param _defaultFee the value for defaultFee
    function configure(
        address _feeAddress,
        Fee calldata _defaultFee
    ) external override onlyOwner {
        require(_feeAddress != address(0), "invalid fee address");

        defaultFee = _defaultFee;
        feeAddress = _feeAddress;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "new owner is the zero address");
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice A function to set the fee value for a token
    /// @param tokenAddress the token address
    /// @param fee the struct value of the token fee
    function setTokenFee(address tokenAddress, Fee calldata fee) external onlyOwner {
        tokenFee[tokenAddress] = fee;
    }

    /// @notice A function to set the defaultFee
    /// @param fee the struct value of the default fee
    function setDefaultFee(Fee calldata fee) external onlyOwner {
        defaultFee = fee;
    }

    /// @notice A function to transfer ERC20 tokens to AnySwap Bridge
    /// @param tokenAddress the token address to be bridged
    /// @param amount token amount to be bridged
    /// @param dcrmAddress AnySwap Bridge Address
    function transfer(
        address tokenAddress,
        uint256 amount,
        address dcrmAddress
    ) external {
        require(dcrmAddress != address(0), "invalid dcrm address");
        require(amount > 0, "invalid amount");

        IERC20 token = IERC20(tokenAddress);

        (uint256 feeAmount, uint256 bridgeAmount) = getFeeAmounts(
            amount,
            tokenAddress
        );
        console.log(feeAmount, bridgeAmount);
        require(token.transferFrom(msg.sender, dcrmAddress, bridgeAmount), "bridge failed");
        require(token.transferFrom(msg.sender, feeAddress, feeAmount), "fee transfer failed");
        emit BridgeDone(msg.sender, dcrmAddress, tokenAddress, bridgeAmount, feeAmount);
    }

    /// @notice A function to transfer native coin to AnySwap Bridge
    function anySwapOutNative(address routerAddress, address anyToken, address recipient, uint256 toChainID) external payable {
        require(routerAddress != address(0), "invalid router address");
        require(msg.value > 0, "invalid amount");

        (uint256 feeAmount, uint256 bridgeAmount) = getFeeAmounts(
            msg.value,
            address(0)
        );

        IAnyswapRouter(routerAddress).anySwapOutNative{value: bridgeAmount}(anyToken, recipient, toChainID);

        (bool feeAmountSent, ) = payable(feeAddress).call{value: feeAmount}("");
        require(feeAmountSent, "fee transfer failed");

        emit BridgeDone(msg.sender, routerAddress, address(0), bridgeAmount, feeAmount);
    }

    function swapOut(address tokenAddress, uint256 amount) external {
        require(amount > 0, "!zero");

        (uint256 feeAmount, uint256 bridgeAmount) = getFeeAmounts(amount, tokenAddress);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), bridgeAmount);
        IERC20(tokenAddress).transferFrom(msg.sender, feeAddress, feeAmount);

        AnyswapERC20(tokenAddress).Swapout(bridgeAmount, msg.sender);

        emit BridgeDone(msg.sender, tokenAddress, tokenAddress, bridgeAmount, feeAmount);
    }

    function anySwapOut(address routerAddress, address anyToken, uint256 amount, uint256 toChainId) external {
        require(amount > 0, "!zero");

        (uint256 feeAmount, uint256 bridgeAmount) = getFeeAmounts(amount, anyToken);
        IERC20(anyToken).transferFrom(msg.sender, address(this), bridgeAmount);
        IERC20(anyToken).transferFrom(msg.sender, feeAddress, feeAmount);

        IAnyswapRouter(routerAddress).anySwapOut(anyToken, msg.sender, bridgeAmount, toChainId);

        emit BridgeDone(msg.sender, routerAddress, anyToken, bridgeAmount, feeAmount);
    }

    function anySwapOutUnderlying(address routerAddress, address anyToken, uint256 amount, uint256 toChainId) external {
        require(amount > 0, "!zero");
        
        address tokenAddress = AnyswapERC20(anyToken).underlying();
        (uint256 feeAmount, uint256 bridgeAmount) = getFeeAmounts(amount, tokenAddress);
        
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), bridgeAmount);
        IERC20(tokenAddress).transferFrom(msg.sender, feeAddress, feeAmount);
        
        IERC20(tokenAddress).approve(routerAddress, bridgeAmount);
        IAnyswapRouter(routerAddress).anySwapOutUnderlying(anyToken, msg.sender, bridgeAmount, toChainId);

        emit BridgeDone(msg.sender, routerAddress, tokenAddress, bridgeAmount, feeAmount);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    /// @param _totalAmount the amount has been transferred to this contract
    /// @param tokenAddress the address of the token
    function getFeeAmounts(
        uint256 _totalAmount,
        address tokenAddress
    ) internal view returns (uint256, uint256) {
        Fee memory fee = tokenFee[tokenAddress];

        if (fee.value == 0) {
            fee = defaultFee;
        }

        uint256 feeAmount;
        uint256 bridgeAmount;
        unchecked {
                 feeAmount = _totalAmount * fee.value / 100 / 10 ** fee.precisions;
      bridgeAmount = _totalAmount - feeAmount;
        }
  

        return (feeAmount, bridgeAmount);
    }
}
