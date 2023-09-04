// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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

contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed;

    function getLatestPrice() public view returns (uint) {
        (, uint price, , , ) = priceFeed.latestRoundData();

        return uint256(price);
    }
}

contract BFMTokenPresale is Ownable, PriceConsumerV3 {
    using SafeMath for uint256;
    uint256 public minbuyToken = 10000e8;
    uint256 public maxbuyToken = 1000000e8;

    enum PresalePhase {
        Phase1,
        Phase2,
        Phase3
    }

    struct PresaleInfo {
        uint256 totalTokens;
        uint256 tokenPrice;
        uint256 releaseStart;
        uint256 releaseDuration;
        uint256 totalSold;
        uint256[] releasedPercentPerMonth;
        uint256 phasetime;
    }

    IERC20 public bfmToken;
    PresaleInfo[3] public presalePhases;

    mapping(address => mapping(uint256 => uint256)) private balances;
    mapping(address => mapping(PresalePhase => uint256))
        private releasedAmounts;
    mapping(address => address) public referrers;

    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 paidAmount,
        PresalePhase phase
    );
    event TokensReleased(
        address indexed buyer,
        uint256 amount,
        PresalePhase phase
    );

    constructor(IERC20 token) {
        bfmToken = token;
        priceFeed = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );

        uint256[] memory p1ReleasedPercentPerMonth = new uint256[](6);
        p1ReleasedPercentPerMonth[0] = 50;
        p1ReleasedPercentPerMonth[1] = 10;
        p1ReleasedPercentPerMonth[2] = 10;
        p1ReleasedPercentPerMonth[3] = 10;
        p1ReleasedPercentPerMonth[4] = 10;
        p1ReleasedPercentPerMonth[5] = 10;

        presalePhases[uint256(PresalePhase.Phase1)] = PresaleInfo(
            3000000 * 1e8,
            14285714285,
            block.timestamp + 1 hours,
            // 9 * 30 days, // Lock period of 9 months
            // 30 days,
            10 minutes,
            0,
            p1ReleasedPercentPerMonth,
            block.timestamp + 1 hours
            //  7 days
        );

        uint256[] memory p2ReleasedPercentPerMonth = new uint256[](6);
        p2ReleasedPercentPerMonth[3] = 10;
        p2ReleasedPercentPerMonth[0] = 50;
        p2ReleasedPercentPerMonth[1] = 10;
        p2ReleasedPercentPerMonth[2] = 10;
        p2ReleasedPercentPerMonth[4] = 10;
        p2ReleasedPercentPerMonth[5] = 10;

        presalePhases[uint256(PresalePhase.Phase2)] = PresaleInfo(
            10000000 * 1e8,
            11111111111,
            presalePhases[uint256(PresalePhase.Phase1)].releaseStart +
                // 6 *30 days, // Lock period of 6 months,
                1 hours,
            // 30 days,
            10 minutes,
            0,
            p2ReleasedPercentPerMonth,
            presalePhases[uint256(PresalePhase.Phase1)].phasetime + 1 hours
            // 21 days
        );

        uint256[] memory p3ReleasedPercentPerMonth = new uint256[](4);
        p3ReleasedPercentPerMonth[0] = 50;
        p3ReleasedPercentPerMonth[1] = 15;
        p3ReleasedPercentPerMonth[2] = 15;
        p3ReleasedPercentPerMonth[3] = 20;
        presalePhases[uint256(PresalePhase.Phase3)] = PresaleInfo(
            17000000 * 1e8,
            9090909090,
            presalePhases[uint256(PresalePhase.Phase2)].releaseStart +
                // 3 * 30 days, // Lock period of 3 months,
                1 hours,
            // 30 days,
            10 minutes,
            0,
            p3ReleasedPercentPerMonth,
            presalePhases[uint256(PresalePhase.Phase2)].phasetime + 1 hours
            // 40 days
        );
    }

    function buyTokensWithReferral(
        PresalePhase phase,
        address referrer
    ) external payable {
        require(referrer != msg.sender, "Cannot refer yourself");
        require(phase == getActivePhase(), "Invalid phase");
        require(
            referrers[msg.sender] == address(0),
            "You already have a referrer"
        );

        referrers[msg.sender] = referrer;
        buyTokens(phase);

        if (referrer != address(0)) {
            uint256 referralReward = msg.value.mul(5).div(100);
            payable(referrer).transfer(referralReward);
        }
    }

    function buyTokens(PresalePhase phase) public payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(phase == getActivePhase(), "Invalid phase");
        PresaleInfo storage presale = presalePhases[uint256(phase)];
        require(block.timestamp < presale.phasetime, "Phase is not active");
        uint256 tokensToBuy = bnbToToken(msg.value, phase);
        require(
            tokensToBuy >= minbuyToken,
            "Minimum purchase is 10,000 tokens"
        );
        require(
            tokensToBuy <= maxbuyToken,
            "Maximum purchase is 1,000,000 tokens"
        );

        require(
            presale.totalSold.add(tokensToBuy) <= presale.totalTokens,
            "Not enough tokens left for sale"
        );

        balances[msg.sender][uint256(phase)] = balances[msg.sender][
            uint256(phase)
        ].add(tokensToBuy);
        presale.totalSold = presale.totalSold.add(tokensToBuy);

        emit TokensPurchased(msg.sender, tokensToBuy, msg.value, phase);
    }

    function bnbToToken(
        uint256 bnb,
        PresalePhase phase
    ) public view returns (uint256) {
        PresaleInfo storage presale = presalePhases[uint256(phase)];
        uint256 bnbToUsd = bnb.mul(getLatestPrice());
        uint256 numberOfTokens = bnbToUsd.mul(presale.tokenPrice);
        return numberOfTokens.div(1e18).div(1e8);
    }

    function releaseTokens(PresalePhase phase) external {
        PresaleInfo storage presale = presalePhases[uint256(phase)];
        require(
            block.timestamp >= presale.releaseStart,
            "Presale for this phase hasn't started yet"
        );
        require(block.timestamp >= presale.phasetime, "Phase Not closed");
        uint256 _releasableAmount = releasableAmount(msg.sender, phase);
        require(_releasableAmount > 0, "No tokens to release");

        releasedAmounts[msg.sender][phase] = releasedAmounts[msg.sender][phase]
            .add(_releasableAmount);
        bfmToken.transferFrom(owner(), msg.sender, _releasableAmount);

        emit TokensReleased(msg.sender, _releasableAmount, phase);
    }

    function releasableAmount(
        address user,
        PresalePhase phase
    ) public view returns (uint256) {
        PresaleInfo storage presale = presalePhases[uint256(phase)];

        uint256 elapsedTime = block.timestamp.sub(presale.releaseStart);
        uint256 releasedMonths = elapsedTime.div(presale.releaseDuration);
        uint256 userPhaseBalance = balances[user][uint256(phase)];

        uint256 totalReleasableAmount = 0;
        for (
            uint256 i = 0;
            i <= releasedMonths && i < presale.releasedPercentPerMonth.length;
            i++
        ) {
            totalReleasableAmount = totalReleasableAmount.add(
                userPhaseBalance.mul(presale.releasedPercentPerMonth[i]).div(
                    100
                )
            );
        }

        return totalReleasableAmount.sub(releasedAmounts[user][phase]);
    }

    function getActivePhase() public view returns (PresalePhase) {
        uint256 currentTimestamp = block.timestamp;
        PresalePhase activePhase = PresalePhase.Phase3;

        for (
            uint256 i = uint256(PresalePhase.Phase1);
            i <= uint256(PresalePhase.Phase3);
            i++
        ) {
            if (
                currentTimestamp < presalePhases[i].phasetime &&
                presalePhases[i].totalSold < presalePhases[i].totalTokens
            ) {
                activePhase = PresalePhase(i);
                break;
            }
        }

        return activePhase;
    }

    function getUserBalanceInfo(
        address user,
        PresalePhase phase
    )
        public
        view
        returns (uint256 totalBalance, uint256 released, uint256 pendingRelease)
    {
        totalBalance = balances[user][uint256(phase)];
        released = releasedAmounts[user][phase];
        pendingRelease = totalBalance.sub(released);
    }

    function withdrawBNB() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function setMinBuyToken(uint256 _newMinBuyToken) external onlyOwner {
        minbuyToken = _newMinBuyToken;
    }

    function setMaxBuyToken(uint256 _newMaxBuyToken) external onlyOwner {
        maxbuyToken = _newMaxBuyToken;
    }

    function setTokenPrice(
        PresalePhase phase,
        uint256 _price
    ) external onlyOwner {
        require(
            phase == PresalePhase.Phase1 ||
                phase == PresalePhase.Phase2 ||
                phase == PresalePhase.Phase3,
            "Invalid phase"
        );
        presalePhases[uint256(phase)].tokenPrice = _price;
    }

    function setReleaseStart(
        PresalePhase phase,
        uint256 _releaseStart
    ) external onlyOwner {
        require(
            phase == PresalePhase.Phase1 ||
                phase == PresalePhase.Phase2 ||
                phase == PresalePhase.Phase3,
            "Invalid phase"
        );
        presalePhases[uint256(phase)].releaseStart =
            block.timestamp +
            _releaseStart;
    }

    function setReleasedPercentPerMonth(
        PresalePhase phase,
        uint256 _releaseDuration
    ) external onlyOwner {
        require(
            phase == PresalePhase.Phase1 ||
                phase == PresalePhase.Phase2 ||
                phase == PresalePhase.Phase3,
            "Invalid phase"
        );
        presalePhases[uint256(phase)].releaseDuration = _releaseDuration;
    }

    function setPhaseTime(
        PresalePhase phase,
        uint256 _phasetime
    ) external onlyOwner {
        require(
            phase == PresalePhase.Phase1 ||
                phase == PresalePhase.Phase2 ||
                phase == PresalePhase.Phase3,
            "Invalid phase"
        );
        presalePhases[uint256(phase)].phasetime = block.timestamp + _phasetime;
    }

    function emergencyWithdrawTokens(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    function setSoldTokenLimits(
        PresalePhase phase,
        uint256 _totalTokens
    ) external onlyOwner {
        require(
            phase == PresalePhase.Phase1 ||
                phase == PresalePhase.Phase2 ||
                phase == PresalePhase.Phase3,
            "Invalid phase"
        );
        require(_totalTokens > 0, "Tokens must be greater than 0");
        presalePhases[uint256(phase)].totalTokens = _totalTokens;
    }
}
