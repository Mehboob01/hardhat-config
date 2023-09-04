// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract MyTo1ken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    bool public isAntiWhaleEnabled;
    uint256 public antiWhaleThreshold;
    uint256 public tax;
    uint256 public limitTaxes = 10000 ether;

    uint256 public rewardTaxPercentage;
    uint256 public investmentTaxPercentage;
    uint256 public maintenanceTaxPercentage;

    uint256 public divided = 100;
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool public SwapEnabled;

    uint256 public launchTimestamp;

    address payable public investmentWallet;
    address payable public maintenanceWallet;
    address payable public rewardWallet;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public ExcludedFromFee;

    event OwnershipRenounced(address indexed previousOwner);
    event investWallet(address indexed wallet);
    event mainWallet(address indexed wallet);
    event marketWallet(address indexed wallet);

    constructor() {
        name = "MyToken";
        symbol = "MTK";
        decimals = 18;
        totalSupply = 1_000_000_000 * 10 ** uint256(decimals);
        balances[owner()] = (totalSupply * 949) / 1000;
        balances[address(this)] = (totalSupply ** 51) / 1000;
        ExcludedFromFee[owner()] = true;
        ExcludedFromFee[address(this)] = true;
        ExcludedFromFee[investmentWallet] = true;
        ExcludedFromFee[maintenanceWallet] = true;
        ExcludedFromFee[rewardWallet] = true;
        launchTimestamp = block.timestamp;

        antiWhaleThreshold = (totalSupply * 5) / 1000; // 0.5% of the total supply
        rewardTaxPercentage = 6;
        investmentTaxPercentage = 12;
        maintenanceTaxPercentage = 12;

        investmentWallet = payable(0xb5fc14ee4DBA399F9043458860734Ed33FdCd96E);
        maintenanceWallet = payable(0x5a8c6eDC91fe3132130899b85c10E77BCEEa17ee);
        rewardWallet = payable(0xc29724f5261faC059A2aA2af88013fDefb7BAae2);

        uniswapV2Router = IUniswapV2Router02(
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        );

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address _owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function setLimitTaxes(uint256 newLimit) external onlyOwner {
        limitTaxes = newLimit;
    }

    function setExcludedFromFee(
        address account,
        bool isExcluded
    ) external onlyOwner {
        if (ExcludedFromFee[account] != isExcluded) {
            ExcludedFromFee[account] = isExcluded;
        } else {
            revert("Exclusion status is already set to the desired value");
        }
    }

    function setAntiWhale(bool enabled, uint256 threshold) external onlyOwner {
        isAntiWhaleEnabled = enabled;
        antiWhaleThreshold = threshold;
    }

    function setInvestmentWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        investmentWallet = payable(wallet);
        emit investWallet(wallet);
    }

    function setMaintenanceWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        maintenanceWallet = payable(wallet);
        emit mainWallet(wallet);
    }

    function setrewardWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        rewardWallet = payable(wallet);
        emit marketWallet(wallet);
    }

    function setTaxPercentages(
        uint256 investmentTax,
        uint256 maintenanceTax,
        uint256 rewardTax
    ) internal {
        // Ensure tax percentages are not greater than 100
        require(
            investmentTax + maintenanceTax + rewardTax <= 100,
            "Total tax exceeds 100%"
        );

        investmentTaxPercentage = investmentTax;
        maintenanceTaxPercentage = maintenanceTax;
        rewardTaxPercentage = rewardTax;
    }

    function updateTaxPercentages(
        uint256 investmentTax,
        uint256 maintenanceTax,
        uint256 rewardTax
    ) external onlyOwner {
        require(SwapEnabled, "Trading has not started yet");
        setTaxPercentages(investmentTax, maintenanceTax, rewardTax);
    }

    function pauseTrading() external onlyOwner {
        require(SwapEnabled, "Trading has not started yet");
        SwapEnabled = false;
    }

    function feesUpdate() external onlyOwner {
        require(
            block.timestamp >= launchTimestamp + 2 minutes,
            "Too early to update fees"
        );
        SwapEnabled = true;
        isAntiWhaleEnabled = true;
        setTaxPercentages(2, 2, 1);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(amount <= balances[from], "Insufficient balance");
        if (from == uniswapV2Pair || to == uniswapV2Pair) {
            if (!ExcludedFromFee[from] && !ExcludedFromFee[to]) {
                uint256 investmentTax = amount.mul(investmentTaxPercentage).div(
                    divided
                ); // 2% Investment
                uint256 buybackTax = amount.mul(maintenanceTaxPercentage).div(
                    divided
                ); // 2% Buybacks
                uint256 rewardTax = amount.mul(rewardTaxPercentage).div(
                    divided
                ); // 1% reward
                tax = tax.add(investmentTax.add(buybackTax).add(rewardTax));
                uint256 transferAmount = amount
                    .sub(investmentTax)
                    .sub(buybackTax)
                    .sub(rewardTax);

                if (isAntiWhaleEnabled) {
                    require(
                        amount <= antiWhaleThreshold,
                        "Transfer amount exceeds the anti-whale threshold"
                    );
                }

                balances[from] = balances[from].sub(amount);
                balances[to] = balances[to].add(transferAmount);
                emit Transfer(from, to, transferAmount);
                balances[address(this)] = balances[address(this)].add(
                    investmentTax.add(buybackTax).add(rewardTax)
                );
                emit Transfer(
                    from,
                    address(this),
                    investmentTax.add(buybackTax).add(rewardTax)
                );
            } else {
                balances[from] = balances[from].sub(amount);
                balances[to] = balances[to].add(amount);
                emit Transfer(from, to, amount);
            }
        } else {
            balances[from] = balances[from].sub(amount);
            balances[to] = balances[to].add(amount);
            emit Transfer(from, to, amount);

            bool shouldSell = tax >= limitTaxes;

            if (SwapEnabled && shouldSell && from != uniswapV2Pair) {
                swapTokensForEth(tax);
                _distributeTax();
                tax = 0;
            }
        }
    }

    function _distributeTax() internal {
        uint256 contractETHBalance = address(this).balance;
        uint256 totaltax = investmentTaxPercentage +
            maintenanceTaxPercentage +
            rewardTaxPercentage;
        uint256 investment = (contractETHBalance)
            .mul(investmentTaxPercentage)
            .div(totaltax);
        uint256 maintenance = (contractETHBalance)
            .mul(maintenanceTaxPercentage)
            .div(totaltax);
        uint256 reward = (contractETHBalance).mul(rewardTaxPercentage).div(
            totaltax
        );

        payable(investmentWallet).transfer(investment);
        payable(maintenanceWallet).transfer(maintenance);
        payable(rewardWallet).transfer(reward);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp + 360
        );
    }

    function withdrawEth(uint256 amount) external onlyOwner {
        require(
            amount <= address(this).balance,
            "Insufficient contract balance"
        );
        payable(msg.sender).transfer(amount);
    }

    uint256 public availableAmount;

    function withdrawMonthly() external {
        uint256 timePassed = block.timestamp - launchTimestamp;
        require(
            timePassed >= 2 minutes,
            "Withdrawal is not yet available for this month"
        );

        uint256 monthsPassed = timePassed / 2 minutes;
        uint256 totalMonths = monthsPassed + 1; // Including the current month

        uint256 monthlyAmount = balances[address(this)] / 12;
        availableAmount = monthlyAmount * totalMonths;

        require(availableAmount > 0, "No funds available for withdrawal");

        balances[address(this)] -= (monthlyAmount * monthsPassed);
        balances[0xb5fc14ee4DBA399F9043458860734Ed33FdCd96E] += (monthlyAmount *
            monthsPassed);

        launchTimestamp += monthsPassed * 2 minutes; // Move to the next eligible month
    }

    receive() external payable {}
}
