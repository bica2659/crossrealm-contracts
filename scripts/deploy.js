const { ethers, upgrades, hardhat: hre } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)));

  // 1. Deploy Rewards
  const Rewards = await ethers.getContractFactory("Rewards");
  const rewards = await upgrades.deployProxy(Rewards, [deployer.address], { initializer: "initialize" });
  await rewards.waitForDeployment();
  const rewardsAddr = await rewards.getAddress();
  console.log("Rewards:", rewardsAddr);

  // 2. Deploy NFT
  const CrossRealmNFT = await ethers.getContractFactory("CrossRealmNFT");
  const nft = await CrossRealmNFT.deploy();
  await nft.waitForDeployment();
  const nftAddr = await nft.getAddress();
  console.log("NFT:", nftAddr);

  // 3. Deploy Staking (CORE as staking/rewards token)
  const CORE_ADDR = "0x0000000000000000000000000000000000000000"; // Native CORE
  const Staking = await ethers.getContractFactory("Staking");
  const staking = await Staking.deploy(CORE_ADDR, CORE_ADDR);
  await staking.waitForDeployment();
  const stakingAddr = await staking.getAddress();
  console.log("Staking:", stakingAddr);

  // 4. Deploy Verifiers
  const ChessVerifier = await ethers.getContractFactory("ChessVerifier");
  const chessVerifier = await ChessVerifier.deploy();
  await chessVerifier.waitForDeployment();
  const chessAddr = await chessVerifier.getAddress();
  console.log("ChessVerifier:", chessAddr);

  const CheckersVerifier = await ethers.getContractFactory("CheckersVerifier");
  const checkersVerifier = await CheckersVerifier.deploy();
  await checkersVerifier.waitForDeployment();
  const checkersAddr = await checkersVerifier.getAddress();
  console.log("CheckersVerifier:", checkersAddr);

  // 5. Deploy Hub
  const Hub = await ethers.getContractFactory("Hub");
  const hub = await upgrades.deployProxy(Hub, [rewardsAddr, nftAddr], { initializer: "initialize" });
  await hub.waitForDeployment();
  const hubAddr = await hub.getAddress();
  console.log("Hub:", hubAddr);

  // 6. Set Hub in Rewards
  const rewardsContract = Rewards.attach(rewardsAddr);
  await (await rewardsContract.setHub(hubAddr)).wait();
  console.log("Hub set in Rewards");

  // 7. Register Verifiers in Hub
  const hubContract = Hub.attach(hubAddr);
  await (await hubContract.registerVerifier("chess", chessAddr)).wait();
  console.log("Chess verifier registered");
  await (await hubContract.registerVerifier("checkers", checkersAddr)).wait();
  console.log("Checkers verifier registered");

  // 8. Verify (optional)
  console.log("\nVerifying...");
  try {
    await hre.run("verify:verify", { address: rewardsAddr, constructorArguments: [deployer.address] });
  } catch (e) { console.log("Rewards skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: nftAddr });
  } catch (e) { console.log("NFT skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: stakingAddr, constructorArguments: [CORE_ADDR, CORE_ADDR] });
  } catch (e) { console.log("Staking skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: chessAddr });
  } catch (e) { console.log("ChessVerifier skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: checkersAddr });
  } catch (e) { console.log("CheckersVerifier skip:", e.message); }
  try {
    await hre.run("verify:verify", { address: hubAddr, constructorArguments: [rewardsAddr, nftAddr] });
  } catch (e) { console.log("Hub skip:", e.message); }

  console.log("\nFull deployment complete! Update index.html with:");
  console.log(`HUB_ADDRESS = '${hubAddr}';`);
  console.log(`REWARDS_ADDRESS = '${rewardsAddr}';`);
  console.log(`NFT_ADDRESS = '${nftAddr}';`);
  console.log(`STAKING_ADDRESS = '${stakingAddr}';`);
  console.log(`VERIFIER_ADDRESSES = { chess: '${chessAddr}', checkers: '${checkersAddr}', fighting: '0x0000000000000000000000000000000000000000', carrace: '0x0000000000000000000000000000000000000000', soccerpenalty: '0x0000000000000000000000000000000000000000', snooker: '0x0000000000000000000000000000000000000000' };`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});