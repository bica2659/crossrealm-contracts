const hre = require("hardhat");

async function main() {
  console.log("Debug: CORE_PRIVATE_KEY loaded?", !!process.env.CORE_PRIVATE_KEY);
  console.log("Debug: Key length (redacted):", process.env.CORE_PRIVATE_KEY ? process.env.CORE_PRIVATE_KEY.length : 0);
  console.log("Debug: Network accounts length:", hre.network.config.accounts.length);

  const signers = await hre.ethers.getSigners();
  console.log("Debug: Signers length:", signers.length);
  if (signers.length > 0) {
    const deployer = signers[0];
    console.log("Deployer address:", deployer.address);
    console.log("Balance:", hre.ethers.utils.formatEther(await deployer.provider.getBalance(deployer.address)));
  } else {
    console.log("Error: No signers loaded—check CORE_PRIVATE_KEY format in .env (64 hex chars, no 0x).");
  }
}

main().catch((error) => {
  console.error(error);
});