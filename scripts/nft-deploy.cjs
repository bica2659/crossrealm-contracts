const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying NFT from:", deployer.address);

  const NFT = await hre.ethers.getContractFactory("CrossRealmNFT");
  const nft = await NFT.deploy();
  await nft.waitForDeployment();
  console.log("NFT deployed to:", await nft.getAddress());

  console.log("\n=== COPY TO FRONTEND ===");
  console.log("NFT_ADDRESS = \"", await nft.getAddress(), "\";");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});