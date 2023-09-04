// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Import the OpenZeppelin ERC20 implementation
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Define a contract that manages ownership
contract Ownable {
    address private owner; // Store the owner's address

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender; // Set the contract deployer as the initial owner
        emit OwnershipTransferred(address(0), owner); // Emit an event indicating ownership transfer
    }

    // Modifier to restrict functions to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Get the current owner's address
    function Owner() public view returns (address) {
        return owner;
    }

    // Transfer ownership to a new address
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner address cannot be zero");
        emit OwnershipTransferred(owner, newOwner); // Emit an event indicating ownership transfer
        owner = newOwner;
    }
    
}

// Define a token contract that inherits from ERC20 and Ownable
contract GLDToken is ERC20, Ownable {

    constructor() ERC20("USDT", "UST") {
        // Mint initial tokens and assign them to the contract deployer
        _mint(_msgSender(), 10000000000 * 10 ** decimals());
    }
   
    // Burn a specific amount of tokens from a specified account
    function burnFrom(address account, uint256 amount) public onlyOwner {
        _burn(account, amount); // Burn tokens from the provided account
    }

    // Mint new tokens and assign them to a specified account
    function mintTo(address account, uint256 amount) public onlyOwner {
        _mint(account, amount); // Mint new tokens and assign to the provided account
    }
    
    
}

