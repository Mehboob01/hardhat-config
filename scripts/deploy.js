const { ethers, run } = require("hardhat");
const axios = require("axios");

async function getEthToUsd() {
  try {
    const response = await axios.get("https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd");
    return response.data.ethereum.usd;
  } catch (error) {
    console.error("Error fetching ETH to USD rate:", error);
    return null;
  }
}

async function getBnbToUsd() {
  try {
    const response = await axios.get("https://api.coingecko.com/api/v3/simple/price?ids=binancecoin&vs_currencies=usd");
    return response.data.binancecoin.usd;
  } catch (error) {
    console.error("Error fetching BNB to USD rate:", error);
    return null;
  }
}

async function main() {
  try {
    const [deployer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();

    console.log("Deploying contracts with the account:", deployer.address);

    const ethToUsdRate = await getEthToUsd();
    if (!ethToUsdRate) {
      console.error("Could not fetch ETH to USD rate. Exiting.");
      process.exit(1);
    }
    console.log("Current ETH to USD rate:", ethToUsdRate);

    const bnbToUsdRate = await getBnbToUsd();
    if (!bnbToUsdRate) {
      console.error("Could not fetch BNB to USD rate. Exiting.");
      process.exit(1);
    }
    console.log("Current BNB to USD rate:", bnbToUsdRate);

    const block = await ethers.provider.getBlock(await ethers.provider.getBlockNumber());
    const timestamp = block.timestamp;

    const blockchainInfo = {
      name: network.name,
      chainId: network.chainId,
      blockNumber: block.number,
      timestamp: timestamp,
    };

    console.log("Blockchain Info:");
    console.table(blockchainInfo);

    const BFMTokenPresale = await ethers.getContractFactory("BFMTokenPresale");

     // Deploy with constructor arguments 42 and "hello"
    //  const name_ = "Benefit Mine";
    //  const symbol_ = "BFM" ;
    //  const decimals_= "8";
    //  const initialBalance_= "100000000000000000";
    //  const tokenOwner = "0xb5fc14ee4DBA399F9043458860734Ed33FdCd96E";
    //  const feeReceiver_= "0xb5fc14ee4DBA399F9043458860734Ed33FdCd96E";
    const tokenAddrss = "0x2748C9980A3A3b8fE44B23a813E06e3149eFb9a6";
 
     const deploymentTx = await BFMTokenPresale.deploy(tokenAddrss);  // 42, "hello"
     await deploymentTx.deployed();
 
     console.log("Contract deployed with address:", deploymentTx.address);
 
     const receipt = await deploymentTx.deployTransaction.wait();
     const gasUsed = receipt.gasUsed;
     console.log("Gas used for deployment:", gasUsed.toString());
 
     const gasPrice = receipt.effectiveGasPrice;
     const transactionFeeEth = ethers.utils.formatEther(gasUsed.mul(gasPrice));
     console.log("Transaction fee (Gas Fee ETH):", transactionFeeEth, "ETH");
 
     // Convert the transaction fee from Ether to USD using the real-time conversion rate
     const transactionFeeUsd = parseFloat(transactionFeeEth) * ethToUsdRate;
     console.log("Transaction fee (Gas Fee USD):", transactionFeeUsd.toFixed(2), "USD");
 
     // Convert the transaction fee from BNB to USD using the real-time conversion rate
     const transactionFeeBnbUsd = parseFloat(transactionFeeEth) * bnbToUsdRate;
     console.log("Transaction fee (Gas Fee BNB-USD):", transactionFeeBnbUsd.toFixed(2), "USD");

    if (network.name !== "hardhat") {
      console.log("Verifying contract on the network...");
      await verifyContract(deploymentTx.address, [tokenAddrss]);
      console.log("Contract verified on the network!");
    }
  } catch (error) {
    console.error("An error occurred:", error);
  }
}

async function verifyContract(contractAddress, constructorArgs) {
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: constructorArgs,
    });
  } catch (error) {
    console.error("Failed to verify contract on the network:", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
