//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

library SafeMath {
    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            uint256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            uint256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Goerli
     * Aggregator: ETH/USD
     * Address: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
     */

    // constructor() {
    //     priceFeed = AggregatorV3Interface(
    //         0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
    //     );
    // }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (uint) {
        (, uint price, , , ) = priceFeed.latestRoundData();

        return price;
    }
}

// 6.3205915e+26
contract preSale is Ownable, PriceConsumerV3 {
    using SafeMath for uint;

    IERC20 public tokenAddress;
    //    uint public price;
    uint public tokenSold;

    address payable public seller;

    event tokenPurchased(address buyer, uint price, uint tokenValue);
    event tokensell(address seller, uint price, uint tokenValue);

    constructor() {
        // tokenAddress = _tokenAddress;
        tokenAddress = IERC20(0x8732B6c3B26f8ff1Cc14576E1d673d8E06f143A5);
        priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        );
        // price= 0.5 ether;
        seller = payable(_msgSender());
    }

    function tokenForSale() public view returns (uint) {
        return tokenAddress.allowance(seller, address(this));
    }

    receive() external payable {
        buy();
    }

    function _buyToken() external payable {
        buy();
    }

    function buy() private {
        require(msg.value > 0, "Enter Creact Price");
        require(_msgSender() != address(0), "Null address can't buy token");
        uint256 price = (getLatestPrice().div(1000e5));
        uint _tokenValue = (msg.value.mul(price));
        require(_tokenValue <= tokenForSale(), "Remaing token less value");
        //   seller.transfer(address(this).balance);
        tokenAddress.transferFrom(seller, _msgSender(), _tokenValue);
        tokenSold = tokenSold.add(_tokenValue);

        emit tokenPurchased(_msgSender(), getLatestPrice(), _tokenValue);
    }

    //    (bool success,)=user.call{value:price}("");
    //    require(success,"success full");
    // require(address(this).balance>= token,"Not enough");

    function sell(uint _tokenValue) public {
        require(_msgSender() != address(0), "Null address can't buy token");
        require(
            tokenAddress.balanceOf(_msgSender()) > 0,
            "Not enough tokens to sell"
        );
        require(address(this).balance != 0);
        uint256 price = (getLatestPrice().div(1000e5));
        uint token = _tokenValue.div(price);
        uint userTokenBalance = tokenAddress.balanceOf(_msgSender());
        require(userTokenBalance >= _tokenValue, "not enough token");
        require(address(this).balance >= token, "Not balance");
        tokenAddress.transferFrom(_msgSender(), address(this), _tokenValue);

        emit tokensell(_msgSender(), token, _tokenValue);
        payable(_msgSender()).transfer(token);
    }

    //   function setSeller(address payable _newSeller) public onlyOwner{
    //     seller = _newSeller;
    //   }
    function setToken(IERC20 _token) public onlyOwner {
        tokenAddress = _token;
    }

    function withdraw(IERC20 _tokenAddress) public onlyOwner returns (bool) {
        uint tokenBalance = _tokenAddress.balanceOf(address(this));
        tokenAddress.transfer(seller, tokenBalance);
        return true;
    }

    function withdrawFunds() public onlyOwner returns (bool) {
        seller.transfer(address(this).balance);
        return true;
    }

    //    function setprice(uint set) public onlyOwner{
    //       price = set;
    //   }
}
