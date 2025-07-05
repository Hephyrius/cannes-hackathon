// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PredictionMarketFactory.sol";

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112;
    }

    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

/**
 * @title PredictionMarketPair
 * @dev Uniswap V2-style pair contract for prediction market tokens
 */
contract PredictionMarketPair is IUniswapV2Pair, IUniswapV2ERC20, ReentrancyGuard {
    // ERC20 state variables
    string public constant override(IUniswapV2ERC20) name = "Prediction Market V2";
    string public constant override(IUniswapV2ERC20) symbol = "PM-V2";
    uint8 public constant override(IUniswapV2ERC20) decimals = 18;
    uint256 public override(IUniswapV2ERC20) totalSupply;
    mapping(address => uint256) public override(IUniswapV2ERC20) balanceOf;
    mapping(address => mapping(address => uint256)) public override(IUniswapV2ERC20) allowance;

    // Permit state variables
    bytes32 public override(IUniswapV2ERC20) DOMAIN_SEPARATOR;
    bytes32 public constant override(IUniswapV2ERC20) PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public override(IUniswapV2ERC20) nonces;

    // Pair state variables
    address public override(IUniswapV2Pair) factory;
    address public override(IUniswapV2Pair) token0;
    address public override(IUniswapV2Pair) token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public override(IUniswapV2Pair) price0CumulativeLast;
    uint256 public override(IUniswapV2Pair) price1CumulativeLast;
    uint256 public override(IUniswapV2Pair) kLast;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "PredictionMarketPair: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view override(IUniswapV2Pair) returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "PredictionMarketPair: TRANSFER_FAILED");
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external override(IUniswapV2Pair) {
        require(msg.sender == factory, "PredictionMarketPair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function _mint(address dst, uint256 amount) internal {
        balanceOf[dst] += amount;
        totalSupply += amount;
        emit Transfer(address(0), dst, amount);
    }

    function _burn(address dst, uint256 amount) internal {
        balanceOf[dst] -= amount;
        totalSupply -= amount;
        emit Transfer(dst, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external override(IUniswapV2ERC20) returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external override(IUniswapV2ERC20) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override(IUniswapV2ERC20) returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override(IUniswapV2ERC20) {
        require(deadline >= block.timestamp, "PredictionMarketPair: EXPIRED");
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, "PredictionMarketPair: INVALID_SIGNATURE");
        _approve(owner, spender, value);
    }

    function mint(address to) external override(IUniswapV2Pair) lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = sqrt(amount0 * amount1) - 1000;
        } else {
            liquidity = min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        require(liquidity > 0, "PredictionMarketPair: INSUFFICIENT_LIQUIDITY_MINTED");

        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * uint256(reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external override(IUniswapV2Pair) lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "PredictionMarketPair: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * uint256(reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external override(IUniswapV2Pair) lock {
        require(amount0Out > 0 || amount1Out > 0, "PredictionMarketPair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "PredictionMarketPair: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "PredictionMarketPair: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) {
                // Call hook if provided
                // IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            }
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "PredictionMarketPair: INSUFFICIENT_INPUT_AMOUNT");
        {
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * 1000**2, "PredictionMarketPair: K");
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function skim(address to) external override(IUniswapV2Pair) lock {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    function sync() external override(IUniswapV2Pair) lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "PredictionMarketPair: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // Simplified price oracle calculation
            price0CumulativeLast += uint256(_reserve1) * timeElapsed;
            price1CumulativeLast += uint256(_reserve0) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = PredictionMarketFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = sqrt(uint256(_reserve0) * uint256(_reserve1));
                uint256 rootKLast = sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function MINIMUM_LIQUIDITY() external pure override(IUniswapV2Pair) returns (uint256) {
        return 1000;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
} 