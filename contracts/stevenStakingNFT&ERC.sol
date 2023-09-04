// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DynamicStakingContract is Ownable {
    using SafeMath for uint256;

    struct TokenInfo {
        address tokenAddress;
        address rewardAddress;
        bool isERC20;
        bool isPaused;
        uint256 duration;
        uint256 defaultNFTReward;
        uint256 ERC20percent;
        mapping(uint256 => uint256) nftPrices;
        uint256[] ids;
    }

    struct StakersData {
        uint256 startTime;
        uint256 endTime;
        uint256 stakedToken;
        uint256 rewardToken;
        address rewardTokenAddress;
        address tokenAddress;
        bool IsStaked;
        uint256 totalWithdrawnAmounts;
        uint256 unStaked;
        uint256 count;
    }

    struct User {
        StakersData[] deposits;
    }

    address[] addressERC;
    address[] addressNFT;
    uint256 Divider = 100_000;

    mapping(address => TokenInfo) private tokens;
    mapping(address => mapping(address => User)) private stakingInfos;
    mapping(address => bool) private hasAddressNFT;
    mapping(address => bool) private hasAddressERc;
    mapping(address => mapping(address => uint256)) public stakedNFTs;

    // Events
    event TokenAdded(address indexed tokenAddress, bool isERC20);
    event NFTPriceSet(
        address indexed tokenAddress,
        uint256 indexed nftId,
        uint256 price
    );
    event TokenPaused(address indexed tokenAddress);
    event TokenUnpaused(address indexed tokenAddress);
    event TokenRemoved(address indexed tokenAddress);
    event StakedERC20(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );
    event UnstakedERC20(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );
    event StakedNFT(
        address indexed user,
        address indexed tokenAddress,
        uint256 nftId
    );
    event UnstakedNFT(
        address indexed user,
        address indexed tokenAddress,
        uint256 nftId
    );
    event WithdrawnERC20(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );
    event WithdrawnNFT(
        address indexed user,
        address indexed tokenAddress,
        uint256 nftId
    );

    // Modifiers
    modifier onlyUnpaused(address tokenAddress) {
        require(!tokens[tokenAddress].isPaused, "Token is paused");
        _;
    }

    function addToken(
        address tokenAddress,
        address rewardAddress,
        uint256[] memory id,
        uint256[] memory reward,
        bool isERC20,
        uint _duration,
        uint defaultReward,
        uint ERC20percent
    ) external onlyOwner {
        require(
            id.length == reward.length,
            "id and reward must be the same length"
        );
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        tokenInfo.tokenAddress = tokenAddress;
        tokenInfo.rewardAddress = rewardAddress;

        if (!hasAddressERc[tokenAddress] && isERC20) {
            hasAddressERc[tokenAddress] = true;
            addressERC.push(tokenAddress);
        }
        if (!hasAddressNFT[tokenAddress] && !isERC20) {
            hasAddressNFT[tokenAddress] = true;
            addressNFT.push(tokenAddress);
        }
        tokenInfo.isERC20 = isERC20;
        tokenInfo.duration = _duration;

        if (isERC20) {
            require(
                ERC20percent > 0 && ERC20percent <= Divider,
                "Invalid ERC20 percent value"
            );
        }
        tokenInfo.ERC20percent = ERC20percent;

        for (uint i = 0; i < reward.length; i++) {
            require(reward[i] > 0, "Reward must be greater than 0");
        }

        if (!isERC20) {
            tokenInfo.defaultNFTReward = defaultReward;
            for (uint i = 0; i < id.length; i++) {
                if (tokenInfo.nftPrices[id[i]] == 0) {
                    tokenInfo.ids.push(id[i]);
                }
                tokenInfo.nftPrices[id[i]] = reward[i]; // Update reward for existing ID
            }
        }
        emit TokenAdded(tokenAddress, isERC20);
    }

    function update(
        address tokenAddress,
        address rewardAddress,
        uint256[] memory id,
        uint256[] memory reward,
        bool isERC20,
        uint _duration,
        uint defaultReward,
        uint ERC20percent,
        bool paus
    ) external onlyOwner {
        require(
            id.length == reward.length,
            "id and reward must be the same length"
        );
        if (!hasAddressNFT[tokenAddress] && !hasAddressERc[tokenAddress]) {
            revert("Token address not added to the list");
        }
        if (isERC20) {
            require(
                ERC20percent > 0 && ERC20percent <= Divider,
                "Invalid ERC20 percent value"
            );
        }
        tokens[tokenAddress].isPaused = paus;
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        tokenInfo.tokenAddress = tokenAddress;
        tokenInfo.rewardAddress = rewardAddress;
        tokenInfo.isERC20 = isERC20;
        tokenInfo.duration = _duration;
        tokenInfo.ERC20percent = ERC20percent;

        for (uint i = 0; i < reward.length; i++) {
            require(reward[i] > 0, "Reward must be greater than 0");
        }

        if (!isERC20) {
            tokenInfo.defaultNFTReward = defaultReward;
            for (uint i = 0; i < id.length; i++) {
                if (tokenInfo.nftPrices[id[i]] == 0) {
                    tokenInfo.ids.push(id[i]);
                }
                tokenInfo.nftPrices[id[i]] = reward[i]; // Update reward for existing ID
            }
        }

        emit TokenAdded(tokenAddress, isERC20);
    }

    function pauseToken(address tokenAddress) external onlyOwner {
        tokens[tokenAddress].isPaused = true;
        emit TokenPaused(tokenAddress);
    }

    function unpauseToken(address tokenAddress) external onlyOwner {
        tokens[tokenAddress].isPaused = false;
        emit TokenUnpaused(tokenAddress);
    }

    function getAddressERC() public view returns (address[] memory) {
        return addressERC;
    }

    function getAddressNFT() public view returns (address[] memory) {
        return addressNFT;
    }

    function getInfoERCandNFT(
        address tokenAddress
    )
        external
        view
        returns (
            address _tokenAddress,
            address _rewardAddress,
            bool _isERC20,
            bool _isPaused,
            uint256 _duration,
            uint256 _defaultNFTReward,
            uint256 _ERC20percent,
            uint256[] memory _ids,
            uint256[] memory _nftPrices
        )
    {
        TokenInfo storage tokenInfo = tokens[tokenAddress];

        _tokenAddress = tokenInfo.tokenAddress;
        _rewardAddress = tokenInfo.rewardAddress;
        _isERC20 = tokenInfo.isERC20;
        _isPaused = tokenInfo.isPaused;
        _duration = tokenInfo.duration;
        _defaultNFTReward = tokenInfo.defaultNFTReward;
        _ERC20percent = tokenInfo.ERC20percent;
        _ids = tokenInfo.ids;

        _nftPrices = new uint256[](tokenInfo.ids.length);
        for (uint256 i = 0; i < tokenInfo.ids.length; i++) {
            _nftPrices[i] = tokenInfo.nftPrices[tokenInfo.ids[i]];
        }
    }

    function stakeERC20(
        address tokenAddress,
        uint amount
    ) external onlyUnpaused(tokenAddress) {
        require(tokens[tokenAddress].isERC20, "Not an ERC20 token");
        require(amount > 0, "Stake amount should be correct");
        require(
            IERC20(tokenAddress).balanceOf(msg.sender) > amount,
            "Insufficient Balance"
        );
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        TokenInfo storage tokenInfo = tokens[tokenAddress];
        uint256 requiredDuration = tokenInfo.duration;
        address rwtokenAddress = tokenInfo.rewardAddress;
        User storage user = stakingInfos[msg.sender][tokenAddress];
        uint256 reward = (amount * tokenInfo.ERC20percent) / Divider;
        user.deposits.push(
            StakersData(
                block.timestamp,
                block.timestamp + requiredDuration,
                amount,
                reward,
                rwtokenAddress,
                tokenAddress,
                true,
                0,
                0,
                user.deposits.length
            )
        );

        emit StakedERC20(msg.sender, tokenAddress, amount);
    }

    function stakeNFT(
        address tokenAddress,
        uint256 nftId
    ) external onlyUnpaused(tokenAddress) {
        require(!tokens[tokenAddress].isERC20, "Not an NFT token");
        require(
            tokens[tokenAddress].nftPrices[nftId] > 0,
            "NFT not listed or price not set"
        );

        TokenInfo storage tokenInfo = tokens[tokenAddress];
        uint256 requiredDuration = tokenInfo.duration;
        address rwtokenAddress = tokenInfo.rewardAddress;
        User storage user = stakingInfos[msg.sender][tokenAddress];

        IERC721(tokenAddress).transferFrom(msg.sender, address(this), nftId);
        stakedNFTs[msg.sender][tokenAddress] = nftId;
        uint256 reward = tokenInfo.nftPrices[nftId] > 0
            ? tokenInfo.nftPrices[nftId]
            : tokenInfo.defaultNFTReward;
        user.deposits.push(
            StakersData(
                block.timestamp,
                block.timestamp + requiredDuration,
                nftId,
                reward,
                rwtokenAddress,
                tokenAddress,
                true,
                0,
                0,
                user.deposits.length
            )
        );

        emit StakedNFT(msg.sender, tokenAddress, nftId);
    }

    function withdrawERC20(address tokenAddress, uint256 depositIndex) public {
        require(
            depositIndex <
                stakingInfos[msg.sender][tokenAddress].deposits.length,
            "Invalid deposit index"
        );
        StakersData storage deposit = stakingInfos[msg.sender][tokenAddress]
            .deposits[depositIndex];
        require(deposit.IsStaked, "No deposit to withdraw");
        require(
            !tokens[tokenAddress].isPaused &&
                block.timestamp >
                stakingInfos[msg.sender][tokenAddress]
                    .deposits[depositIndex]
                    .endTime,
            "Not a Paused token"
        );
        uint256 amount = deposit.stakedToken;
        uint256 rewardamount = deposit.rewardToken;
        IERC20(tokenAddress).transfer(msg.sender, amount);
        IERC20(tokens[tokenAddress].rewardAddress).transferFrom(
            owner(),
            msg.sender,
            rewardamount
        );
        deposit.IsStaked = false;
        deposit.totalWithdrawnAmounts = amount + rewardamount;

        emit WithdrawnERC20(msg.sender, tokenAddress, amount);
    }

    function withdrawNFT(address tokenAddress, uint256 depositIndex) external {
        StakersData[] storage deposits = stakingInfos[msg.sender][tokenAddress]
            .deposits;
        require(depositIndex < deposits.length, "Invalid deposit index");
        StakersData storage deposit = deposits[depositIndex];
        uint nftId = deposit.stakedToken;
        require(
            block.timestamp >= deposit.endTime,
            "Staking duration not reached"
        );
        require(
            !tokens[tokenAddress].isPaused &&
                block.timestamp >
                stakingInfos[msg.sender][tokenAddress]
                    .deposits[depositIndex]
                    .endTime,
            "Not a Paused token"
        );
        uint256 rewardamount = deposit.rewardToken;
        IERC721(tokenAddress).transferFrom(address(this), msg.sender, nftId);
        IERC20(tokens[tokenAddress].rewardAddress).transferFrom(
            owner(),
            msg.sender,
            rewardamount
        );

        deposits[depositIndex] = deposits[deposits.length - 1];
        deposit.IsStaked = false;
        deposit.totalWithdrawnAmounts = nftId;
        emit WithdrawnNFT(msg.sender, tokenAddress, nftId);
    }

    function unstakeERC20(address tokenAddress, uint256 count) external {
        StakersData[] storage userDeposits = stakingInfos[msg.sender][
            tokenAddress
        ].deposits;
        require(tokens[tokenAddress].isERC20, "Not an ERC20 token");
        require(
            tokens[tokenAddress].isPaused ||
                block.timestamp <
                stakingInfos[msg.sender][tokenAddress].deposits[count].endTime,
            "Not a Paused token"
        );

        if (userDeposits[count].IsStaked) {
            userDeposits[count].unStaked += userDeposits[count].stakedToken;
            userDeposits[count].IsStaked = false;
            emit UnstakedERC20( msg.sender,tokenAddress,userDeposits[count].stakedToken);
        }
        IERC20(tokenAddress).transfer(
            msg.sender,
            userDeposits[count].stakedToken
        );
        
    }

    function unstakeNFT(address tokenAddress, uint256 count) external {
        require(!tokens[tokenAddress].isERC20, "Not an NFT token");
        require(
            tokens[tokenAddress].isPaused ||
                block.timestamp <
                stakingInfos[msg.sender][tokenAddress].deposits[count].endTime,
            "Not a Paused token"
        );
        require(
            stakingInfos[msg.sender][tokenAddress].deposits[count].IsStaked,
            "already withdrawn"
        );

        uint256 nftId = stakedNFTs[msg.sender][tokenAddress];
        require(nftId != 0, "No NFT staked");

        stakedNFTs[msg.sender][tokenAddress] = 0;
        IERC721(tokenAddress).transferFrom(address(this), msg.sender, nftId);
        stakingInfos[msg.sender][tokenAddress].deposits[count].IsStaked = false;
        stakingInfos[msg.sender][tokenAddress].deposits[count].unStaked = nftId;

         emit UnstakedNFT(msg.sender, tokenAddress, nftId);
    }

    function getStakeDetailsERC(
        address _user
    ) public view returns (StakersData[] memory) {
        uint256 totalStakeDetails;

        for (uint256 i = 0; i < addressERC.length; i++) {
            totalStakeDetails += stakingInfos[_user][addressERC[i]]
                .deposits
                .length;
        }

        StakersData[] memory allStakeDetails = new StakersData[](
            totalStakeDetails
        );
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < addressERC.length; i++) {
            StakersData[] storage userStakeDetails = stakingInfos[_user][
                addressERC[i]
            ].deposits;
            uint256 stakingInfoCount = userStakeDetails.length;

            for (uint256 j = 0; j < stakingInfoCount; j++) {
                allStakeDetails[currentIndex] = userStakeDetails[j];
                currentIndex++;
            }
        }

        return allStakeDetails;
    }

    function getStakeDetailsNFT(
        address _user
    ) public view returns (StakersData[] memory) {
        uint256 totalStakeDetails;

        for (uint256 i = 0; i < addressNFT.length; i++) {
            totalStakeDetails += stakingInfos[_user][addressNFT[i]]
                .deposits
                .length;
        }

        StakersData[] memory allStakeDetails = new StakersData[](
            totalStakeDetails
        );
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < addressNFT.length; i++) {
            StakersData[] storage userStakeDetails = stakingInfos[_user][
                addressNFT[i]
            ].deposits;
            uint256 stakingInfoCount = userStakeDetails.length;

            for (uint256 j = 0; j < stakingInfoCount; j++) {
                allStakeDetails[currentIndex] = userStakeDetails[j];
                currentIndex++;
            }
        }

        return allStakeDetails;
    }

    function removeToken(address tokenAddress) external onlyOwner {
        TokenInfo storage tokenInfo = tokens[tokenAddress];

        require(tokenInfo.tokenAddress != address(0), "Token not found");

        tokenInfo.tokenAddress = address(0);
        tokenInfo.rewardAddress = address(0);

        tokenInfo.duration = 0;
        tokenInfo.ERC20percent = 0;

        if (tokenInfo.isERC20) {
            hasAddressERc[tokenAddress] = false;
            addressERC.pop();
            removeAddressFromArray(tokenAddress, addressERC);
        } else {
            hasAddressNFT[tokenAddress] = false;
            removeAddressFromArray(tokenAddress, addressNFT);

            for (uint i = 0; i < tokenInfo.ids.length; i++) {
                delete tokenInfo.nftPrices[tokenInfo.ids[i]];
            }

            delete tokenInfo.ids;
            tokenInfo.defaultNFTReward = 0;
        }

        emit TokenRemoved(tokenAddress);
    }

    function removeAddressFromArray(
        address addr,
        address[] storage array
    ) internal {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == addr) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }

    function getTokenInfo(
        address tokenAddress
    ) external view returns (address _tokenAddress, uint256[] memory ids) {
        TokenInfo storage tokenInfo = tokens[tokenAddress];
        return (tokenInfo.tokenAddress, tokenInfo.ids);
    }

    function userERCdetails(
        address _user,
        address tokenAddress
    ) external view returns (StakersData[] memory) {
        return (stakingInfos[_user][tokenAddress].deposits);
    }
}