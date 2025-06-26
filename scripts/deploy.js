const hre = require("hardhat");

async function main() {
  const SubscriptionPlatform = await hre.ethers.getContractFactory("SubscriptionPlatform");

  const subscriptionFeeInWei = hre.ethers.utils.parseEther("0.01"); // 0.01 ETH
  const contract = await SubscriptionPlatform.deploy(subscriptionFeeInWei);

  await contract.deployed();

  console.log("SubscriptionPlatform deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
