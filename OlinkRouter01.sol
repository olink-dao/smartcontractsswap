pragma solidity >=0.6.6;

import '../olink-swap-core/interfaces/IOlinkFactory.sol';
import '../olink-swap-lib/utils/TransferHelper.sol';

import './interfaces/IOlinkRouter02.sol';
import './libraries/OlinkLibrary.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract OlinkRouter02 is IOlinkRouter02 {  // only for OLINK <-> USDT
    using SafeMath for uint;

    address public owner;

    uint256 public backBuyRatio = 10;        // 1% for buy
    uint256 public backSellRatio = 10;       // 1% for sell
    uint256 public eco1BuyRatio = 10;        // 1% for buy eco 1
    uint256 public eco1SellRatio = 10;       // 1% for sell eco 1
    uint256 public eco2BuyRatio = 10;        // 1% for buy eco 2
    uint256 public eco2SellRatio = 10;       // 1% for sell eco 2
    address payable public receiverEco1;     // eco1 receiver
    address payable public receiverEco2;     // eco2 receiver

    mapping(address => bool) public whites;   // white user

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'OlinkRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;

        owner = msg.sender;
    }

    modifier onlyOwner() {
	    require(msg.sender == owner);
	    _;
	}

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function setOwner(address ownerAddress) external onlyOwner {
		require(ownerAddress != address(0), "owner can't be null");
		owner = ownerAddress;
	}

	function setBackBuyRatio(uint256 ratio) external onlyOwner {
		require(ratio < 1000, "ratio can't be greater than 1000");
		backBuyRatio = ratio;
	}

	function setBackSellRatio(uint256 ratio) external onlyOwner {
		require(ratio < 1000, "ratio can't be greater than 1000");
		backSellRatio = ratio;
	}

	function setEco1BuyRatio(uint256 ratio) external onlyOwner {
		require(ratio < 1000, "ratio can't be greater than 1000");
		eco1BuyRatio = ratio;
	}

	function setEco1SellRatio(uint256 ratio) external onlyOwner {
		require(ratio < 1000, "ratio can't be greater than 1000");
		eco1SellRatio = ratio;
	}

	function setEco2BuyRatio(uint256 ratio) external onlyOwner {
		require(ratio < 1000, "ratio can't be greater than 1000");
		eco2BuyRatio = ratio;
	}

	function setEco2SellRatio(uint256 ratio) external onlyOwner {
		require(ratio < 1000, "ratio can't be greater than 1000");
		eco2SellRatio = ratio;
	}

	function setEco1Receiver(address payable receiver) external onlyOwner {
		require(receiver != address(0), "receiver can't be zero");
		receiverEco1 = receiver;
	}

	function setEco2Receiver(address payable receiver) external onlyOwner {
		require(receiver != address(0), "receiver can't be zero");
		receiverEco2 = receiver;
	}

	function setWhite(address _addr, bool flag) external onlyOwner {
		whites[_addr] = flag;
	}

    // **** For web ****
    function getReserves(address tokenA, address tokenB) external view returns(uint amountA, uint amountB) {
    	(amountA, amountB) = OlinkLibrary.getReserves(factory, tokenA, tokenB);
    }

    function getTotalSupply(address tokenA, address tokenB) external view returns(uint totalSupply) {
    	totalSupply = OlinkLibrary.getTotalSupply(factory, tokenA, tokenB);
    }

    function getLpBalance(address tokenA, address tokenB, address addr) external view returns(uint balance) {
    	balance = OlinkLibrary.getLpBalance(factory, tokenA, tokenB, addr);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IOlinkFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IOlinkFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = OlinkLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = OlinkLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'OlinkRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = OlinkLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'OlinkRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = OlinkLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IOlinkPair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = OlinkLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IOlinkPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = OlinkLibrary.pairFor(factory, tokenA, tokenB);
        IOlinkPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IOlinkPair(pair).burn(to);
        (address token0,) = OlinkLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'OlinkRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'OlinkRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = OlinkLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IOlinkPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = OlinkLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IOlinkPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = OlinkLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IOlinkPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = OlinkLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? OlinkLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IOlinkPair(OlinkLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = OlinkLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'OlinkRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OlinkLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = OlinkLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'OlinkRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OlinkLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)  // OLINK -> USDT
    {
        require(path[0] == WETH, 'OlinkRouter: INVALID_PATH');

        if(!whites[to]) {
	        if(receiverEco1 != address(0) && eco1SellRatio > 0) {
	        	receiverEco1.transfer(msg.value * eco1SellRatio / 1000);
	        }
	        if(receiverEco2 != address(0) && eco2SellRatio > 0) {
	        	receiverEco2.transfer(msg.value * eco2SellRatio / 1000);
	        }
	    }

        uint256 realRatio = (!whites[to]) ? (1000 - eco1SellRatio - eco2SellRatio - backSellRatio) : 1000;
        amounts = OlinkLibrary.getAmountsOut(factory, msg.value * realRatio / 1000, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'OlinkRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: ((!whites[to]) ? amounts[0] + msg.value * backSellRatio / 1000 : amounts[0])}();
        assert(IWETH(WETH).transfer(OlinkLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        if(!whites[to]) {
        	assert(IWETH(WETH).transfer(OlinkLibrary.pairFor(factory, path[0], path[1]), msg.value * backSellRatio / 1000));
        }
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'OlinkRouter: INVALID_PATH');
        amounts = OlinkLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'OlinkRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OlinkLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)  // USDT -> OLINK
    {
        require(path[path.length - 1] == WETH, 'OlinkRouter: INVALID_PATH');

        if(!whites[to]) {
	        if(receiverEco1 != address(0) && eco1BuyRatio > 0) {
		        TransferHelper.safeTransferFrom(
		            path[0], msg.sender, receiverEco1, amountIn * eco1BuyRatio / 1000
		        );
	        }
	        if(receiverEco2 != address(0) && eco2BuyRatio > 0) {
	        	TransferHelper.safeTransferFrom(
		            path[0], msg.sender, receiverEco2, amountIn * eco2BuyRatio / 1000
		        );
	        }
	    }
	    uint256 realRatio = (!whites[to]) ? (1000 - eco1BuyRatio - eco2BuyRatio - backBuyRatio) : 1000;
        amounts = OlinkLibrary.getAmountsOut(factory, amountIn *  realRatio / 1000, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'OlinkRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OlinkLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        if(!whites[to]) {
	        TransferHelper.safeTransferFrom(
	            path[0], msg.sender, OlinkLibrary.pairFor(factory, path[0], path[1]), amountIn * backBuyRatio / 1000
	        );
	    }
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'OlinkRouter: INVALID_PATH');
        amounts = OlinkLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'OlinkRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(OlinkLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = OlinkLibrary.sortTokens(input, output);
            IOlinkPair pair = IOlinkPair(OlinkLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = OlinkLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? OlinkLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OlinkLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'OlinkRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'OlinkRouter: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(OlinkLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'OlinkRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'OlinkRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, OlinkLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'OlinkRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return OlinkLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return OlinkLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return OlinkLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return OlinkLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return OlinkLibrary.getAmountsIn(factory, amountOut, path);
    }
}
