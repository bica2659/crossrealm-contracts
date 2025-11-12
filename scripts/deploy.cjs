const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying from:", deployer.address);

  // 1. Rewards (dev = deployer)
  const Rewards = await hre.ethers.getContractFactory("Rewards");
  const rewards = await Rewards.deploy(deployer.address);
  await rewards.waitForDeployment();
  console.log("Rewards deployed to:", await rewards.getAddress());

  // 2. Hub (pass Rewards addr)
  const Hub = await hre.ethers.getContractFactory("Hub");
  const hub = await Hub.deploy(await rewards.getAddress());
  await hub.waitForDeployment();
  console.log("Hub deployed to:", await hub.getAddress());

  // Update Rewards with Hub addr
  await rewards.setHub(await hub.getAddress());
  console.log("Rewards updated with Hub addr");

  // 3. NFT
  const NFT = await hre.ethers.getContractFactory("CrossRealmNFT");
  const nft = await NFT.deploy();
  await nft.waitForDeployment();
  console.log("NFT deployed to:", await nft.getAddress());

  console.log("\n=== COPY TO FRONTEND HTML (Replace '0x...') ===");
  console.log("HUB_ADDRESS = \"", await hub.getAddress(), "\";");
  console.log("REWARDS_ADDR = \"", await rewards.getAddress(), "\";");
  console.log("NFT_ADDRESS = \"", await nft.getAddress(), "\";");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});